#!/usr/bin/perl

use strict;
use warnings;

use LWP::Simple;
use File::Temp qw/ tempdir /;
use Archive::Extract;
 
my $dir = tempdir();
my $filename = "$dir/02packages.details.txt.gz";
my $db_file = 'cpan_names.db';
 
my $status = getstore(
                "http://www.cpan.org/modules/02packages.details.txt.gz",
                $filename
             );
 
if ( is_success($status) )
{
    print "file downloaded correctly at: $filename\n";

    my $ae = Archive::Extract->new( archive => $filename );
    my $ok = $ae->extract( to => $dir );

    if ($ok) {
        print "unpacked\n";

        use DBI;
        unlink $db_file if -e $db_file;
        my $db = DBI->connect("dbi:SQLite:$db_file", "", "",
        {RaiseError => 1, AutoCommit => 1});
        $db->do("CREATE TABLE names (
                                     module  VARCHAR(200),
                                     release VARCHAR(100)
                                    )"
               );

        my %double_entry = ();
        open (my $f, "$dir/02packages.details.txt");
        while (<$f>) {
            if ($_ =~
                 m/^([\w:]+)\s+[\w\d\.]+\s+\w{1}\/\w{2}\/\w+\/([\w-]+)\d+/
               ) {
                my $module  = $1;
                my $release = $2;
                chop($release);

                unless (exists $double_entry{"$module-$release"}) {
                    $db->do("INSERT INTO names
                                VALUES ('$module', '$release')"
                           );
                    $double_entry{"$module-$release"} = 1;
                }
            }
        }
        close ($f); 
        print "filled into DB\n";

        my $all = $db->selectall_arrayref("SELECT * FROM names");

        # select release from names where module='EBook::MOBI';
        foreach my $row (@$all) {
            my ($mod, $rel) = @$row;
            print "$mod\t$rel\n";
        }

        $db->disconnect;

    }
}
else
{
    print "error downloading file to $filename: $status\n";
}

