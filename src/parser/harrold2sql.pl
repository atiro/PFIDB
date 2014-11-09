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

Script to convert Private Finance Initative data from Alice Harrold spreadsheet from https://www.google.com/fusiontables/DataSource?docid=1eTZcuQ2Ti09HjDL3Nvordv9jExWiswA9Du6DWmw4#card:id=2 into SQLite data for ease of use.

=cut

my $csv_file = shift or die "No CVS filename given, exiting"; 
my $output_file = shift or die "No SQLite output filename given, exiting";

my @projects;
my $dbh;

Log::Log4perl->easy_init($WARN);

=head2 parse_pfi

This function parses the PFI CVS file (from Excel). The row format is:

=begin text
0 -  HMT  -Id  
1 - Project name
2 - Address 
3 - Completed Addres ? 
4 - Complete Num
5 - Duplicate?
6 - Links
7 - Department
8 - Procuring authority
9 - Sector
10 - Constituency
11 - Region
12 - Project Status
13 - Date Fin Close
14 - Date Construction Complete
15 - First Date of Operations
16 - Operational period of contract (years)
17 - Capital Value (£m)
18 - Total Repayments
19 - Capital to repayment ratio
20 - Payment 1992-93 (£m)
21 - Payment 1993-94 (£m)
22 - Payment 1994-95 (£m)
23 - Payment 1995-96 (£m)
24 - Payment 1996-97 (£m)
25 - Payment 1998-99 (£m)
26 - Payment 1999-00 (£m)
27 - Payment 2000-01 (£m)
28 - Payment 2001-02 (£m)
29 - Payment 2002-03 (£m)
30 - Payment 2003-04 (£m)
31 - Payment 2004-05 (£m)
32 - Payment 2005-06 (£m)
33 - Payment 2006-07 (£m)
34 - Payment 2007-08 (£m)
35 - Payment 2008-09 (£m)
36 - Payment 2010-11 (£m)
37 - Payment 2011-02 (£m)
38 - Payment 2012-03 (£m)
39 - Estimated Payment 2013-14 (£m)
40 - Estimated Payment 2014-15 (£m)
41 - Estimated Payment 2015-16 (£m)
42 - Estimated Payment 2016-17 (£m)
43 - Estimated Payment 2017-18 (£m)
44 - Estimated Payment 2018-19 (£m)
45 - Estimated Payment 2019-20 (£m)
46 - Estimated Payment 2020-21 (£m)
47 - Estimated Payment 2021-22 (£m)
48 - Estimated Payment 2022-23 (£m)
49 - Estimated Payment 2023-24 (£m)
50 - Estimated Payment 2024-25 (£m)
51 - Estimated Payment 2025-26 (£m)
52 - Estimated Payment 2026-27 (£m)
53 - Estimated Payment 2027-28 (£m)
54 - Estimated Payment 2028-29 (£m)
55 - Estimated Payment 2029-30 (£m)
56 - Estimated Payment 2030-31 (£m)
57 - Estimated Payment 2031-32 (£m)
58 - Estimated Payment 2032-33 (£m)
59 - Estimated Payment 2033-34 (£m)
60 - Estimated Payment 2034-35 (£m)
61 - Estimated Payment 2035-36 (£m)
62 - Estimated Payment 2036-37 (£m)
63 - Estimated Payment 2037-38 (£m)
64 - Estimated Payment 2038-39 (£m)
65 - Estimated Payment 2039-40 (£m)
66 - Estimated Payment 2040-41 (£m)
67 - Estimated Payment 2041-42 (£m)
68 - Estimated Payment 2042-43 (£m)
69 - Estimated Payment 2043-44 (£m)
70 - Estimated Payment 2044-45 (£m)
71 - Estimated Payment 2045-46 (£m)
72 - Estimated Payment 2046-47 (£m)
73 - Estimated Payment 2047-48 (£m)
74 - Estimated Payment 2048-49 (£m)
75 - Estimated Payment 2049-50 (£m)
76 - Estimated Payment 2050-51 (£m)
77 - Estimated Payment 2051-52 (£m)
78 - Estimated Payment 2052-53 (£m)
79 - Estimated Payment 2053-54 (£m)
80 - Estimated Payment 2054-55 (£m)
81 - Estimated Payment 2055-56 (£m)
82 - Estimated Payment 2056-57 (£m)
83 - Estimated Payment 2057-58 (£m)
84 - Estimated Payment 2058-59 (£m)
85 - Estimated Payment 2059-60 (£m)
86 - Equity Holder 1 Name
87 - Equity Holder 1 Share %
88 - Equity Holder 1 : Change of Ownership since March 2011?
89 - Info 1
90 - Equity Holder 2 Name
91 - Equity Holder 2 Share %
92 - Equity Holder 2 : Change of Ownership since March 2011?
93 - Info 2
94 - Equity Holder 3 Name
95 - Equity Holder 3 Share %
96 - Equity Holder 3 : Change of Ownership since March 2011?
97 - Info 3
98 - Equity Holder 4 Name
99 - Equity Holder 4 Share %
100 - Equity Holder 4 : Change of Ownership since March 2011?
101 - Info 4
102 - Equity Holder 5 Name
103 - Equity Holder 5 Share %
104 - Equity Holder 5 : Change of Ownership since March 2011?
105 - Info 6
106 - Equity Holder 6 Name
107 - Equity Holder 6 Share %
108 - Equity Holder 6 : Change of Ownership since March 2011?
109 - Info 6
110 - SPV Name
111 - SPV Company number
112 - SPV Address

=cut

sub parse_projects {
       my $file = shift;
       my $csv = Text::CSV->new( { binary => 1 });

       open my $fh, "<$file" or die "Failed to open file $file: aborting - $!";
       while ( my $row = $csv->getline( $fh ) ) {
            push @projects, $row;
       }
       $csv->eof or $csv->error_diag();
       close($fh);
    
};

sub create_db {
        my $file = shift;

        $dbh = DBI->connect("dbi:SQLite:dbname=$file", "", "");

        $dbh->do('ALTER TABLE project ADD COLUMN address VARCHAR(255)');


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

        DEBUG "Adding address toprojects";

        my $sth2 = $dbh->prepare_cached('UPDATE project SET address = ? WHERE hmt_id = ?');

        for my $row (@projects) {
                # Cleanup dates - if not in valid YYYY-MM-DD format drop
		my $hmt_id = undef;

		# Hardcoded recognition of some projects to tie tables together, not possible automaitcally as no columns in common
		# and financial close dates don't seem to match

		if(defined($row->[2]) && defined($row->[0])) {
 	               $sth2->execute($row->[2], $row->[0]);
		}
	}
}

# TODO GetOpt

#$db = DBIx::Simple->connect("dbi:SQLite:dbname=pfi_projects.db", "", "");

#create_db("pfi_projects.db");
create_db($output_file);

#parse_pfi("pfi.csv");
parse_projects($csv_file);

populate_db();
