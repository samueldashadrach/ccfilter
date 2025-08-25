#!/usr/bin/env perl

# written by gpt-5, may contain hallucins, not tested

use strict;
use warnings;
use Regexp::Assemble;

# Preserve exact bytes (including CRLF)
binmode(STDIN,  ':raw');
binmode(STDOUT, ':raw');

# Load domains from a newline-separated text file (first argument)
my $domains_file = shift @ARGV // '';
exit 2 unless $domains_file ne '';
open my $dfh, '<', $domains_file or exit 2;

# Build a trie-based regex over all domains (case-insensitive match will be handled by /i)
my $ra = Regexp::Assemble->new;
my $have_domains = 0;
while (my $line = <$dfh>) {
    $line =~ s/\r?\n\z//;
    $line =~ s/^\s+|\s+$//g;
    next if $line eq '' || $line =~ /^#/;
    my $d = lc $line;             # normalize case for hostnames
    $ra->add(quotemeta($d));      # treat as a literal string
    $have_domains = 1;
}
close $dfh;

# If no domains, create a never-matching regex
my $DOMAIN_RE = $have_domains ? $ra->re : qr/(?!)/;

# Single precompiled regex:
# - start of line (m) with exactly one space after the colon
# - optional scheme
# - zero or more RFC-compliant subdomain labels (1–63 chars, alnum with internal hyphens, not leading/trailing) + dot
# - one of the domains (trie-compressed)
# - boundary after the domain: / ? # : CR LF or end
my $TARGET_URI_RE = qr/^WARC-Target-URI:\x20(?:https?:\/\/)?(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)*$DOMAIN_RE(?=[\/?#:]|\r|\n|$)/mi;

sub emit_if_match {
    my ($rec) = @_;
    return unless length $rec;
    print $rec if $rec =~ $TARGET_URI_RE;
}

my $delim = "\r\n\r\nWARC/1.0";  # delimiter belongs to the start of the next record
my $dlen  = length($delim);
my $buf   = '';

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