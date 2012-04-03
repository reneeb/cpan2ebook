#!/usr/bin/perl

use LWP::Simple;
use File::Temp qw/ tempdir /;
use Archive::Extract;
 
$dir = tempdir();
$filename = "$dir/02packages.details.txt.gz";
 
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
        print "ok\n";

        open (my $f, "$dir/02packages.details.txt");
        while (<$f>) {
            if ($_ =~
                 m/^([\w:]+)\s+[\w\d\.]+\s+\w{1}\/\w{2}\/\w+\/([\w-]+)\d+/
               ) {
                my $module = $1;
                my $release = $2;
                chop($release);
                print "$module\t->\t$release\n";
            }
        }
        close ($f); 
    }
}
else
{
    print "error downloading file to $filename: $status\n";
}

