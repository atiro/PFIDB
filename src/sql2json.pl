#!/usr/bin/perl

use strict;
use v5.10;
use DBD::SQLite;
use JSON;

my $projects;

my $db_file = shift or die "Failed to provide database file";
my $json_file = shift or die "Failed to provide output json filename";

my $dbh = DBI->connect("dbi:SQLite:dbname=$db_file", "", "");

sub read_database() {
    my $query = "SELECT project.hmt_id,project.name as name,department.name as dept_name,authority.name as auth_name,sector.name as sector_name,constituency.name as constituency_name,region.name as region_name, status, date_ojeu, date_pref_bid, date_fin_close, date_cons_complete, date_ops, contract_years, off_balance_IFRS, off_balance_ESA95, off_balance_GAAP, capital_value, spv.name from project,department,authority,sector,constituency,region,spv WHERE project.department_id = department.id AND project.authority_id = authority.id AND project.sector_id = sector.id AND project.constituency_id = constituency.id AND project.region_id = region.id AND project.spv_id = spv.id GROUP BY project.hmt_id";
    $projects = $dbh->selectall_arrayref($query);
};

sub emit_json() {
    my $json = JSON->new->allow_nonref;
    open my $fh, ">$json_file" or die "Failed to open output file $json_file - $!\n";
    print $fh $json->pretty->encode( $projects );
    close($fh);
    
};

read_database();

emit_json();
