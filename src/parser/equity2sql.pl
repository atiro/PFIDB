#!/usr/bin/perl

use Modern::Perl '2014';
use Text::CSV;
use DBD::SQLite;
#use Test::Simple;
use Scalar::Util qw(looks_like_number);
use Log::Log4perl qw(:easy);
#use GetOpt::Long;


=encoding utf8

=head1 PFI2CVS

Script to convert Private Finance Initative Equity transactions spreadsheet from http://www.european-services-strategy.org.uk/ppp-database/ppp-equity-database/ into SQLite data for ease of use.

=cut

my $csv_file = shift or die "No CVS filename given, exiting"; 
my $output_file = shift or die "No SQLite output filename given, exiting";

my @equity;
my $dbh;

Log::Log4perl->easy_init($WARN);

=head2 parse_pfi

This function parses the PFI CVS file (from Excel). The row format is:

=begin text
0 - Transaction number
1 - Date of Sale of Equity
2 - Vendor
3 - PPP Project
4 - No of PPP (?)
5 - Date of financial closure of project
6 - Purchaser of Equity
7 - % share holding sold 
8 - Price £m
9 - Profit £m
10 - Avg time between financial closure & sale of equity (years)
11 - Annual rate of return at time of equity sale
12 - Source 1
13 - Source 2
14 - Source 3

=end text

=cut

=head2 parse_pfi

Parse the Equity data in a CSV file

=cut

sub parse_equity {
       my $file = shift;
       my $csv = Text::CSV->new( { binary => 1 });

       open my $fh, "<$file" or die "Failed to open file $file: aborting - $!";
       while ( my $row = $csv->getline( $fh ) ) {
            push @equity, $row;
       }
       $csv->eof or $csv->error_diag();
       close($fh);
    
};

=head2 create_db

Create the database & tables

=cut

sub create_db {
        my $file = shift;

        $dbh = DBI->connect("dbi:SQLite:dbname=$file", "", "");

        $dbh->do('CREATE TABLE equity_transaction (transaction_id INTEGER PRIMARY KEY, hmt_id INTEGER, date_of_sale date, vendor_id INTEGER, name VARCHAR(255), num_ppp INTEGER, date_fin_close date, purchaser_id INTEGER, share_holding_sold REAL, price REAL, price_net_liabilities boolean, profit REAL, avg_time_sale_years REAL, avg_rate_return REAL, source1 VARCHAR(255), source2 VARCHAR(255), source3 VARCHAR(255))');

}

=head2 verify_date

Helper function to check dates are in right format

=cut

sub verify_date {
        my $csv_date = shift;

        if($csv_date =~ /\d{4}-\d{2}-\d{2}/) {
            return $csv_date;
        }

        WARN "Unknown date format - $csv_date - marking as null";

        return undef; 
}

sub verify_bool {
        my $csv_bool = shift;

        if(uc($csv_bool) eq "ON") {
            return 1;
        } elsif(uc($csv_bool) eq "OFF") {
            return 0;
        }

        WARN "Unknown bool format - $csv_bool - marking as null";

        return undef;
}

=head2 populate_db

Fill the database tables with information from the PFI spreadsheet

=cut

sub populate_db {

        my %companies = ();

        DEBUG "Inserting projects";

        my $sth2 = $dbh->prepare_cached('INSERT INTO equity_transaction VALUES (?, ?, ? , ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');

        for my $row (@equity) {
                # Cleanup dates - if not in valid YYYY-MM-DD format drop
                my $date_sale = verify_date($row->[8]);
                my $date_fin_close = verify_date($row->[10]);
		my $hmt_id = undef;
		my $vendor_id = undef;
		my $purchaser_id = undef;
		my $price_net_liabilities = 0;

		# Hardcoded recognition of some projects to tie tables together, not possible automaitcally as no columns in common
		# and financial close dates don't seem to match

		if($row->[3] =~ /Parc/) {
			# Query db for HMP Parc Project
			$hmt_id = 484
		}

                if($companies{$row->[2]}) {
                   $vendor_id = $companies{$row->[2]};
                   DEBUG "Using existing value $vendor_id";
                } else {
		   DEBUG "Checking if company already exists";
		   my $sth = $dbh->prepare("SELECT count(*) from company WHERE name = ?");
		   $sth->execute($row->[2]);
		   my($results) = $sth->fetchrow_array();
		   if($results > 0) {
		   	my $sth = $dbh->prepare("SELECT id from company WHERE name = ?");
		   	$sth->execute($row->[2]);
		   	($vendor_id) = $sth->fetchrow_array();
		   } else {
                   	my $sth = $dbh->prepare("INSERT INTO company (name) VALUES (?)");
                   	$sth->execute($row->[2]);
                   	$companies{$row->[2]} = $dbh->last_insert_id(undef, undef, undef, undef);
                   	DEBUG "Name: $row->[2] : $companies{$row->[2]}";
                   	$vendor_id = $companies{$row->[2]}
		  }
                }

                if($companies{$row->[6]}) {
                   $purchaser_id = $companies{$row->[6]};
                   DEBUG "Using existing value $purchaser_id";
                } else {
		   DEBUG "Checking if company already exists";
		   my $sth = $dbh->prepare("SELECT count(*) from company WHERE name = ?");
		   $sth->execute($row->[6]);
		   my($results) = $sth->fetchrow_array();
		   if($results > 0) {
		   	my $sth = $dbh->prepare("SELECT id from company WHERE name = ?");
		   	$sth->execute($row->[6]);
		   	($purchaser_id) = $sth->fetchrow_array();
		   } else {
                   	my $sth = $dbh->prepare("INSERT INTO company (name) VALUES (?)");
                   	$sth->execute($row->[6]);
                   	$companies{$row->[6]} = $dbh->last_insert_id(undef, undef, undef, undef);
                   	DEBUG "Name: $row->[6] : $companies{$row->[6]}";
                   	$purchaser_id = $companies{$row->[6]}
		  }
                }

		# Lookup vendor in companies (or SPV?)
		# Lookup purchase (6) in companies (or SPV?)

		if($row->[8] =~ /liabilities/) { 
			$price_net_liabilities = 1;
			$row->[8] =~ s/[^\d.]//g;
		}

                $sth2->execute($row->[0], $hmt_id, $date_sale, $vendor_id, $row->[3], $row->[4], $date_fin_close, $purchaser_id, $row->[7], $row->[8],
				$price_net_liabilities, $row->[9], $row->[10], $row->[11], $row->[12], $row->[13], $row->[14]);
				
                $dbh->commit();
	}

}

# TODO GetOpt

#$db = DBIx::Simple->connect("dbi:SQLite:dbname=pfi_projects.db", "", "");

#create_db("pfi_projects.db");
create_db($output_file);

#parse_pfi("pfi.csv");
parse_equity($csv_file);

populate_db();
