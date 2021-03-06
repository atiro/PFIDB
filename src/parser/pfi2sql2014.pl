#!/usr/bin/perl

use Modern::Perl '2014';
use Text::CSV;
use DBD::SQLite;
use SQL::Interp;
use Test::Simple;
use Scalar::Util qw(looks_like_number);
use List::MoreUtils qw{natatime};
use Log::Log4perl qw(:easy);
#use GetOpt::Long;


=encoding utf8

=head1 PFI2CVS

Script to convert Private Finance Initative Excel spreadsheet from data.gov.uk into SQLite data for ease of use

=cut

my $csv_file = shift or die "No CVS filename given, exiting"; 
my $output_file = shift or die "No SQLite output filename given, exiting";

my @projects;
my $dbh;

Log::Log4perl->easy_init($WARN);

=head2 parse_pfi

This function parses the PFI CVS file (from Excel). The row format is:

=begin text

0 Unique HMT Project ID
1 Project Name
2 Department
3 Procuring authority
4 Sector
5 Constituency
6 Region
7 Project Status
8 Date Of OJEU
9 Date of preferred bidder
10 Date of financial close
11 Date of construction completion
12 First date of operations
13 Operational period of contract (years)
14 On / Off balance sheet under IFRS
15 On / Off balance sheet under ESA 95
16 On / Off balance sheet under UK GAAP
17 Capital Value (£m)
18 Unitary charge payment 1992-93 (£m)
19 Unitary charge payment 1993-94 (£m)
20 Unitary charge payment 1994-95 (£m)
21 Unitary charge payment 1995-96 (£m)
22 Unitary charge payment 1996-97 (£m)
23 Unitary charge payment 1997-98 (£m)
24 Unitary charge payment 1998-99 (£m)
25 Unitary charge payment 1999-00 (£m)
26 Unitary charge payment 2000-01 (£m)
27 Unitary charge payment 2001-02 (£m)
28 Unitary charge payment 2002-03 (£m)
29 Unitary charge payment 2003-04 (£m)
30 Unitary charge payment 2004-05 (£m)
31 Unitary charge payment 2005-06 (£m)
32 Unitary charge payment 2006-07 (£m)
33 Unitary charge payment 2007-08 (£m)
34 Unitary charge payment 2008-09 (£m)
35 Unitary charge payment 2009-10 (£m)
36 Unitary charge payment 2010-11 (£m)
37 Unitary charge payment 2011-12 (£m)
38 Unitary charge payment 2012-13 (£m)
39 Unitary charge payment 2013-14 (£m)
40 Estimated unitary charge payment 2014-15 (£m)
41 Estimated unitary charge payment 2015-16 (£m)
42 Estimated unitary charge payment 2016-17 (£m)
43 Estimated unitary charge payment 2017-18 (£m)
44 Estimated unitary charge payment 2018-19 (£m)
45 Estimated unitary charge payment 2019-20 (£m)
46 Estimated unitary charge payment 2020-21 (£m)
47 Estimated unitary charge payment 2021-22 (£m)
48 Estimated unitary charge payment 2022-23 (£m)
49 Estimated unitary charge payment 2023-24 (£m)
50 Estimated unitary charge payment 2024-25 (£m)
51 Estimated unitary charge payment 2025-26 (£m)
52 Estimated unitary charge payment 2026-27 (£m)
53 Estimated unitary charge payment 2027-28 (£m)
54 Estimated unitary charge payment 2028-29 (£m)
55 Estimated unitary charge payment 2029-30 (£m)
56 Estimated unitary charge payment 2030-31 (£m)
57 Estimated unitary charge payment 2031-32 (£m)
58 Estimated unitary charge payment 2032-33 (£m)
59 Estimated unitary charge payment 2033-34 (£m)
60 Estimated unitary charge payment 2034-35 (£m)
61 Estimated unitary charge payment 2035-36 (£m)
62 Estimated unitary charge payment 2036-37 (£m)
63 Estimated unitary charge payment 2037-38 (£m)
64 Estimated unitary charge payment 2038-39 (£m)
65 Estimated unitary charge payment 2039-40 (£m)
66 Estimated unitary charge payment 2040-41 (£m)
67 Estimated unitary charge payment 2041-42 (£m)
68 Estimated unitary charge payment 2042-43 (£m)
69 Estimated unitary charge payment 2043-44 (£m)
70 Estimated unitary charge payment 2044-45 (£m)
71 Estimated unitary charge payment 2045-46 (£m)
72 Estimated unitary charge payment 2046-47 (£m)
73 Estimated unitary charge payment 2047-48 (£m)
74 Estimated unitary charge payment 2048-49 (£m)
75 Estimated unitary charge payment 2049-50 (£m)
76 Estimated unitary charge payment 2050-51 (£m)
77 Estimated unitary charge payment 2051-52 (£m)
78 Estimated unitary charge payment 2052-53 (£m)
79 Estimated unitary charge payment 2053-54 (£m)
80 Estimated unitary charge payment 2054-55 (£m)
81 Estimated unitary charge payment 2055-56 (£m)
82 Estimated unitary charge payment 2056-57 (£m)
83 Estimated unitary charge payment 2057-58 (£m)
84 Estimated unitary charge payment 2058-59 (£m)
85 Estimated unitary charge payment 2059-60 (£m)
86 Equity holder 1: Name
87 Equity holder 1: Equity share (%)
88 Equity holder 2: Name
89 Equity holder 2: Equity share (%)
90 Equity holder 3: Name
91 Equity holder 3: Equity share (%)
92 Equity holder 4: Name
93 Equity holder 4: Equity share (%)
94 Equity holder 5: Name
95 Equity holder 5: Equity share (%)
96 Equity holder 6: Name
97 Equity holder 6: Equity share (%)
98 SPV name
99 SPV company number
100 SPV address

=end text

=cut

=head2 parse_pfi

Parse the PFI data in a CSV file

=cut

sub parse_pfi {
       my $file = shift;
       my $csv = Text::CSV->new( { binary => 1 });

       open my $fh, "<$file" or die "Failed to open file $file: aborting - $!";
       while ( my $row = $csv->getline( $fh ) ) {
            push @projects, $row;
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

        $dbh->do('CREATE TABLE project (hmt_id INTEGER, name VARCHAR(255), department_id INTEGER, authority_id INTEGER, sector_id INTEGER, constituency_id INTEGER, region_id INTEGER, status VARCHAR(64), date_ojeu date, date_pref_bid date, date_fin_close date, date_cons_complete date, date_ops date, contract_years INTEGER, off_balance_IFRS BOOL, off_balance_ESA95 BOOL, off_balance_GAAP BOOL, capital_value INTEGER, spv_id INTEGER)');
        $dbh->do('CREATE TABLE department (id INTEGER PRIMARY KEY, name VARCHAR(255))');
        $dbh->do('CREATE TABLE authority (id INTEGER PRIMARY KEY, name VARCHAR(255))');
        $dbh->do('CREATE TABLE sector (id INTEGER PRIMARY KEY, name VARCHAR(255))');
        $dbh->do('CREATE TABLE constituency (id INTEGER PRIMARY KEY, name VARCHAR(255))');
        $dbh->do('CREATE TABLE region (id INTEGER PRIMARY KEY, name VARCHAR(255))');
        $dbh->do('CREATE TABLE payment (id INTEGER PRIMARY KEY, proj_id INTEGER, year INTEGER, estimated INTEGER)');
        $dbh->do('CREATE TABLE company (id INTEGER PRIMARY KEY, name VARCHAR(255))');
        $dbh->do('CREATE TABLE equity (id INTEGER PRIMARY KEY, proj_id INTEGER, company_id INTEGER, share INTEGER)');
        $dbh->do('CREATE TABLE spv (id INTEGER PRIMARY KEY, spv_id INTEGER, name VARCHAR(255), address VARCHAR(255))');

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

        # Extract unique departments
        my %departments = %{{ map { $_->[2] => 1 } @projects}};

        $dbh->begin_work();
        my $sth = $dbh->prepare_cached('INSERT INTO department (id, name) VALUES (NULL, ?)');

        for my $dept ( keys %departments ) {
            $sth->execute($dept);
            $departments{$dept} = $dbh->last_insert_id(undef, undef, undef, undef);
            ERROR "Dept: $dept ($departments{$dept})";
        }
        $dbh->commit();

        # Extract unique sector 
        my %sectors = %{{ map { $_->[4] => 1 } @projects}};

        $sth = $dbh->prepare_cached('INSERT INTO sector (name) VALUES (?)');

        for my $sector ( keys %sectors ) {
            $sth->execute($sector);
            DEBUG "Sector: $sector";
            $sectors{$sector} = $dbh->last_insert_id(undef, undef, undef, undef);
        }

        # Extract unique regions 
        my %regions = %{{ map { $_->[6] => 1 } @projects}};

        $sth = $dbh->prepare_cached('INSERT INTO region (name) VALUES (?)');

        for my $region ( keys %regions ) {
            $sth->execute($region);
            DEBUG "Region: $region";
            $regions{$region} = $dbh->last_insert_id(undef, undef, undef, undef);
        }

        # Extract unique procuring authority
        my %authorities = %{{ map { $_->[3] => 1 } @projects}};

        $sth = $dbh->prepare_cached('INSERT INTO authority (name) VALUES (?)');

        for my $authority ( keys %authorities ) {
            DEBUG "Authority: $authority";
            $sth->execute($authority);
            $authorities{$authority} = $dbh->last_insert_id(undef, undef, undef, undef);
        }

        # Extract unique constituency
        my %constituencies = %{{ map { $_->[5] => 1 } @projects}};

        $sth = $dbh->prepare_cached('INSERT INTO constituency (name) VALUES (?)');

        for my $constituency ( keys %constituencies ) {
            $sth->execute($constituency);
            DEBUG "Constituency: $constituency";
            $constituencies{$constituency} = $dbh->last_insert_id(undef, undef, undef, undef);
        }

        # Extract unique SPV name
        my %spvs = %{{ map { $_->[98] => [ $_->[99], $_->[100] ] }@projects}};

        $sth = $dbh->prepare_cached('INSERT INTO spv (spv_id, name, address) VALUES (?,?,?)');
        for my $spv ( keys %spvs ) {
            $sth->execute($spvs{$spv}->[0], $spv, $spvs{$spv}->[1]);
            $spvs{$spv} = $dbh->last_insert_id(undef, undef, undef, undef);
            DEBUG "SPV: $spv";
        }

        $sth = $dbh->prepare_cached('INSERT INTO payment VALUES (?, ?, ?, ?)');

        my %companies = ();

        DEBUG "Inserting projects";

        my $sth2 = $dbh->prepare_cached('INSERT INTO project VALUES (?, ?, ?, ?, ? , ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');

        for my $row (@projects) {
                # Cleanup dates - if not in valid YYYY-MM-DD format drop
                my $date_ojeu = verify_date($row->[8]);
                my $date_pref_bid = verify_date($row->[9]);
                my $date_fin_close = verify_date($row->[10]);
                my $date_cons_complete = verify_date($row->[11]);
                my $date_ops = verify_date($row->[12]);
                my $contract_years = $row->[13]; # TODO Check is valid number
                my $off_balance_IFRS = verify_bool($row->[14]);
                my $off_balance_ESA95 = verify_bool($row->[15]);
                my $off_balance_GAAP = verify_bool($row->[16]);
                my $capital_value = undef;
                my $spv = undef;

                if(looks_like_number($row->[17])) {
                    $capital_value = $row->[17]
                }

                if($spvs{$row->[98]}) {
                    $spv = $spvs{$row->[98]};
                }

                $sth2->execute($row->[0], $row->[1], $departments{$row->[2]}, $authorities{$row->[3]}, $sectors{$row->[4]}, $constituencies{$row->[5]}, $regions{$row->[6]}, $row->[7], $date_ojeu, $date_pref_bid, $date_fin_close, $date_cons_complete, $date_ops, $contract_years, $off_balance_IFRS, $off_balance_ESA95, $off_balance_GAAP, $capital_value, $spv);

                my $payment_year = 1992;
                my $payment_total = 0;

                $dbh->begin_work();

                for my $payment (@$row[18..85]) {
                    if(looks_like_number($payment)) {
                      $sth->execute(undef, $row->[0], $payment_year, $payment);
                      $payment_total += $payment;
                    } else {
                      WARN "Ignoring non-number ($payment) payment value";
                    }
                    $payment_year++;
                }

                $dbh->commit();

                DEBUG "Inserting payments";

                my $sth2 = $dbh->prepare_cached('INSERT INTO equity VALUES (?, ?, ?, ?)');
                my @equity = @$row[86..97];

                my $it = natatime 2, @equity;

                $dbh->begin_work();

                while (my @vals = $it->()) {
                        my $company_id;

                        if($companies{$vals[0]}) {
                            $company_id = $companies{$vals[0]};
                            DEBUG "Using existing value $company_id";
                        } else {
                            my $sth = $dbh->prepare("INSERT INTO company (name) VALUES (?)");
                            $sth->execute($vals[0]);
                            $companies{$vals[0]} = $dbh->last_insert_id(undef, undef, undef, undef);
                            DEBUG "Name: $vals[0] : $companies{$vals[0]}";
                            $company_id = $companies{$vals[0]}
                        }

                        $sth2->execute(undef, $row->[0], $company_id, 
                                                         $vals[1]); 
                }

                $dbh->commit();
    };

}

# TODO GetOpt

#$db = DBIx::Simple->connect("dbi:SQLite:dbname=pfi_projects.db", "", "");

#create_db("pfi_projects.db");
create_db($output_file);

#parse_pfi("pfi.csv");
parse_pfi($csv_file);



populate_db();
