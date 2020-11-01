use strict;
use warnings;

use Test::More;

use JSON::PrettyCompact;
use JSON::MaybeXS;

my $jxs = JSON::MaybeXS->new()->canonical(1);

my (@ds) = (
    {},
    { a => 1 },
    { a => 1, b => {} },
    {
        a => 1,
        b => { c => 1 },
        d => [1],
        e => [ 1, 2 ],
        f => [ 1, 2, 3 ],
        g => [ 1 .. 10 ]
    },
    {
        a => 1,
        b => { c => 1 },
        d => [1],
        e => [ 1, 2 ],
        f => [ 1, 2, 3 ],
        g => [ 1 .. 10 ],
        h => [ map { { a => 1 } } 1 ],
        i => [ map { { a => 1 } } 1, 2 ],
        j => [ map { { a => 1 } } 1 .. 10 ],
        j => [
            ( map { { a => 1 } } 1 .. 5 ),
            { b => { c => { d => { e => [ 1 .. 10 ] } } } },
            map { { f => 1 } } 1 .. 5
        ],
        k => {
            a => 1,
            b => 2,
            c => 3,
            d => 4,
            e => 5,
            f => 6,
        },

    }
);

for my $width ( 5, 10, 20, 30, 40, 50, 60, 70 ) {
    my $instance =
      JSON::PrettyCompact->new( width => $width, width_is_local => 1 );

    for my $test_no ( 0 .. $#ds ) {
        my $encoded      = $instance->encode( $ds[$test_no] );
        my $pure_encoded = $jxs->encode( $ds[$test_no] );
        my $round_trip   = $jxs->encode( $jxs->decode($encoded) );
        is( $pure_encoded, $round_trip,
"Round trip for data $test_no encoded value is the same as native encoding with width $width"
        );
    }
}

done_testing;
