#!/usr/bin/env perl
use strict;
use warnings;

use LWP::Simple "get";
use Term::ANSIColor;

# Constants
use constant baseURL => "http://apod.nasa.gov/apod";
use constant indexURI => "archivepix.html";

# Globals
my $pictureCount = 0;
my $downloadCount = 0;
my $debug = 0;
my $maxDownloadCount = 10;

my $numberWidth = 3;
my $textWidth = 60;
my $totalWidth = $numberWidth + $textWidth + 3;

# Parse command arguments
while($_ = shift @ARGV) {
    if(/^-d$/) {
        $debug = 1;
    }
    if(/^-n$/) {
        $maxDownloadCount = shift;
        die "Error: maximum count is not a number\n" unless $maxDownloadCount =~ /^\d+$/;
    }
    if(/^-h$/) {
        print "Script for downloading the Astronomy Picture of the Day Archive\n";
        print "Created by Waldo Plasmatics\n";
        print "Usage: $0 [-d] [-n count]\n";
        print "Options:\n";
        print "\t-d\t\tdebug flag: writes log files if a picture could not be downloaded\n";
        print "\t-n count\tcount flag: lets you specify the amount of downloaded pictures (default = 10)\n";
        exit 0;
    }
}

# Get the index
printf "%-${totalWidth}s ", "Downloading index...";
my $indexURL = sprintf "%s/%s", baseURL, indexURI;
my @indexContents = split(/^/, get($indexURL)) or die colored ['red'], "ERROR\n";
print colored ['green'], "OK\n";

# Parse index
my $i = 0;
while($i < @indexContents && $downloadCount < $maxDownloadCount) {
    $_ = $indexContents[$i++];
    if(/^\s*(\w[\w\s]+\w)\s*:\s*<a\s+href="(ap\d+.html)">(.+)<\/a>/) {
        # Get article contents
        my ($articleDate, $articleURI, $articleTitle) = ($1, $2, $3);
        printf "[%-${numberWidth}i] %-${textWidth}s ", ++$pictureCount, $articleTitle;

        # Only if picture does not exists
        my $imageFilename = $articleTitle . ".jpg";
        if(!-e $imageFilename) {
            # Get article contents
            my $articleURL = sprintf "%s/%s", baseURL, $articleURI;
            my @articleContents = split(/^/, get($articleURL)) or die colored ['red'], "ERROR\n";

            # Parse article contents
            my $j = 0;
            my $downloaded = 0;
            while($j < @articleContents && !$downloaded) {
                $_ = $articleContents[$j++];
                if(/href="(image\/\w+\/[^\/\."]+\.jpg)"/) {
                    # Download image
                    my $imageURL = sprintf "%s/%s", baseURL, $1;
                    print colored ['yellow'], "DOWLOADING ";
                    printf "(%s)\n", $imageURL;
                    `curl $imageURL -# -o "$imageFilename"`;

                    $downloadCount++;
                    $downloaded = 1;
                }
            }

            # If download failed => show error message
            if(!$downloaded) {
                if($debug) {
                    my $log = "$i.log";
                    print colored ['red'], "ERROR ";
                    printf "(%s)\n", $log;
                    open(FH, ">", $log);
                    printf FH "<!-- Source: %s -->\n", $articleURL;
                    print FH join "\n", @articleContents;
                    close(FH);
                }
                else {
                    print colored ['red'], "ERROR\n";
                }
            }
        }
        else {
            print colored ['green'], "OK\n";
            $downloadCount++;
        }

        if($downloadCount % 10 == 0 && $downloadCount != $maxDownloadCount) {
            my ($dirSize) = (`du -h .` =~ /(\d+\w+)/);
            print "Downloaded $downloadCount pictures ($dirSize)\n";
        }

        if($downloadCount == $maxDownloadCount) {
            my ($dirSize) = (`du -h -c .|tail -n 1` =~ /(\d+\w+)/);
            print "Downloaded $downloadCount pictures ($dirSize). Continue?\n > ";
            my $answer = <STDIN>;
            $maxDownloadCount += 10 if $answer =~ /^\s*((y(es)?)|(ja?))\s*$/;
        }
    }
}
