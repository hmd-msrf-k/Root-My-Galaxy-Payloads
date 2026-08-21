#!/usr/bin/env perl
use strict;
use warnings;

@ARGV == 3 or die "usage: $0 RAW_IMAGE PROBE_OFFSET OUTPUT_HEADER\n";
my ($image_path, $probe_text, $output_path) = @ARGV;

$probe_text =~ /\A(?:0x)?[0-9a-fA-F]+\z/
    or die "invalid probe offset: $probe_text\n";
my $probe_offset = hex($probe_text);

open my $image_fh, '<:raw', $image_path or die "open $image_path: $!\n";
local $/;
my $image = <$image_fh>;
close $image_fh or die "close $image_path: $!\n";

my @page_offsets = (0x000, 0x200, 0x400, 0x600, 0x800, 0xa00, 0xc00, 0xe00);

# Use 0x2000 step
my $step = 0x2000;
my $rows = int(0x1f0000 / $step) + 1;

my @rows;
for my $slide (map { $_ * $step } 0 .. $rows - 1) {
    my $page_source = $probe_offset - $slide;
    $page_source >= 0 or die "slide 0x$slide exceeds probe offset\n";

    my @words;
    for my $page_offset (@page_offsets) {
        my $source_offset = $page_source + $page_offset;
        push @words, unpack('Q<', substr($image, $source_offset, 8));
    }
    push @rows, [$slide, $page_source, \@words];
}

open my $out, '>', $output_path or die "open $output_path: $!\n";
print {$out} <<"HEADER";
// Generated from the exact raw Image.
// 0x2000 step fingerprint table.
#ifndef P0_FINGERPRINT_H
#define P0_FINGERPRINT_H

#define P0_FINGERPRINT_WORDS 8

static const uint16_t p0_fingerprint_offsets[P0_FINGERPRINT_WORDS] = {
  0x000, 0x200, 0x400, 0x600, 0x800, 0xa00, 0xc00, 0xe00,
};

struct p0_fingerprint {
  uintptr_t slide;
  uint64_t words[P0_FINGERPRINT_WORDS];
};

static const struct p0_fingerprint p0_fingerprints[] = {
HEADER
for my $row (@rows) {
    my ($slide, undef, $words) = @$row;
    printf {$out} "  { 0x%06xULL, { ", $slide;
    for my $index (0 .. $#$words) {
        printf {$out} "0x%016xULL", $words->[$index];
        print {$out} $index == $#$words ? " } },\n" : $index % 2 == 1 ? ",\n    " : ", ";
    }
}
print {$out} <<'FOOTER';
};

#endif
FOOTER
close $out or die "close $output_path: $!\n";
printf "generated %d rows with 0x2000 step\n", scalar(@rows);
