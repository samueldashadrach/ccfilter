#!/usr/bin/env perl

# written by gpt-5, may contain hallucins, successfully tested

use strict;
use warnings;

# Preserve exact bytes (including CRLF)
binmode(STDIN,  ':raw');
binmode(STDOUT, ':raw');

# Load domains from a newline-separated text file (first argument)
my $domains_file = shift @ARGV // '';
exit 2 unless $domains_file ne '';
open my $dfh, '<', $domains_file or exit 2;
my @domains;
while (my $line = <$dfh>) {
    $line =~ s/\r?\n\z//;
    $line =~ s/^\s+|\s+$//g;
    next if $line eq '' || $line =~ /^#/;
    push @domains, lc $line;
}
close $dfh;

my $delim = "\r\n\r\nWARC/1.0";  # delimiter belongs to the start of the next record
my $dlen  = length($delim);
my $buf   = '';

sub emit_if_match {
    my ($rec) = @_;
    return unless length $rec;

    my ($uri) = $rec =~ /^WARC-Target-URI:\s*(\S+)/mi;
    return unless defined $uri && length $uri;

    my $u = lc $uri;
    for my $d (@domains) {
        my $dd = lc $d;
        if (
            index($u, "$dd")              != -1 ||
            index($u, "http://$dd")       != -1 ||
            index($u, "https://$dd")      != -1 ||
            index($u, "http://www.$dd")   != -1 ||
            index($u, "https://www.$dd")  != -1
        ) {
            print $rec;
            last;
        }
    }
}

my $chunk;
while (read(STDIN, $chunk, 65536)) {
    $buf .= $chunk;

    while (1) {
        # If buffer starts with the delimiter, search for the next one after it
        my $search_from = (length($buf) >= $dlen && substr($buf, 0, $dlen) eq $delim) ? $dlen : 0;
        my $next = index($buf, $delim, $search_from);
        last if $next == -1;

        # Emit everything up to (but not including) the next delimiter
        my $rec = substr($buf, 0, $next);
        emit_if_match($rec);

        # Remove emitted segment; leave the next record (starting with $delim) in buffer
        substr($buf, 0, $next) = '';
    }
}

# Emit the final record
emit_if_match($buf) if length $buf;
