use 5.006;    # our
use strict;
use warnings;

package JSON::PrettyCompact;

our $VERSION = '0.001000';

# ABSTRACT: More Compact, But still Pretty, JSON

# AUTHORITY

sub new {
    my ( $class, @args ) = @_;
    my (%params) = ref $args[0] ? %{ $args[0] } : @args;
    my $self = bless {}, $class;
    my (%defaults) = (
        canonical      => 1,
        indent         => 2,
        space_after    => 1,
        space_before   => 0,
        width          => 69,    # This width is um, nice.
        width_is_local => 1,
        fold_hashes    => 1,
        fold_arrays    => 1,
    );
    for ( keys %defaults ) {
        $self->{$_} = exists $params{$_} ? $params{$_} : $defaults{$_};
    }
    require JSON::MaybeXS;
    $self->{_encoder} =
      JSON::MaybeXS->new()->pretty(0)->canonical( $self->{canonical} )
      ->space_before( $self->{space_before} )
      ->space_after( $self->{space_after} );

    $self->{_variable_encoder} =
      JSON::MaybeXS->new()->pretty(0)->allow_nonref(1);
    return $self;
}

sub encode { $_[0]->_encode_width( $_[1], $_[0]->{width} ) }

sub _encode_array_width {
    my (@values) = @{ $_[1] };
    return "[]" unless @values;

    my $space =
      $_[0]->{width_is_local} ? $_[0]->{width} : $_[2] - $_[0]->{indent};
    my $inline_comma = ( $_[0]->{space_after} ? q[, ] : q[,] );
    my $comma_size   = length $inline_comma;

    my (@entries);
    for my $value (@values) {
        my $entry = $_[0]->_encode_width( $value, $space );
        $entry =~ s/\s*\Z//ms;

        if (    @entries
            and $_[0]->{fold_arrays}
            and $entries[-1] !~ /\n/
            and $entry !~ /\n/
            and $space >=
            ( length($entry) + $comma_size + length( $entries[-1] ) ) )
        {
            # tack on to previous
            $entries[-1] .= $inline_comma . $entry;
            next;
        }

        # apply indent
        push @entries, join "\n",
          map { " " x $_[0]->{indent} . $_ } split /\n/, $entry;
    }
    return "[\n" . ( join qq[,\n], @entries ) . "\n]";
}

sub _encode_hash_width {
    my (@keys) = $_[0]->{canonical} ? sort keys %{ $_[1] } : keys %{ $_[1] };
    return "{}" unless @keys;

    my $inline_comma = ( $_[0]->{space_after} ? q[, ] : q[,] );
    my $comma_size   = length $inline_comma;

    my (@entries);
    for my $key (@keys) {
        my $label = $_[0]->{_variable_encoder}->encode($key);
        $label .= " " if $_[0]->{space_before};
        $label .= ":";
        $label .= " " if $_[0]->{space_after};

        my $space =
            $_[0]->{width_is_local}
          ? $_[0]->{width}
          : $_[2] - length($label) - $_[0]->{indent};
        my $entry = $label . $_[0]->_encode_width( $_[1]->{$key}, $space );
        $entry =~ s/\s*\Z//ms;

        if (    @entries
            and $_[0]->{fold_hashes}
            and $entries[-1] !~ /\n/
            and $entry !~ /\n/
            and $space >=
            ( length($entry) + $comma_size + length( $entries[-1] ) ) )
        {
            # tack on to previous
            $entries[-1] .= $inline_comma . $entry;
            next;
        }

        # apply indent
        push @entries, join "\n",
          map { " " x $_[0]->{indent} . $_ } split /\n/, $entry;
    }
    return "{\n" . ( join qq[,\n], @entries ) . "\n}";
}

sub _encode_width {
    return $_[0]->{_variable_encoder}->encode( $_[1] ) if not ref $_[1];
    my $test_encoding = $_[0]->{_encoder}->encode( $_[1] );
    return $test_encoding if $_[2] >= length $test_encoding;
    return $_[0]->_encode_hash_width( $_[1], $_[2] )
      if 'HASH' eq ref $_[1];
    return $_[0]->_encode_array_width( $_[1], $_[2] )
      if 'ARRAY' eq ref $_[1];
    die "Can't encode ref type " . ref $_[1];
}
1;
