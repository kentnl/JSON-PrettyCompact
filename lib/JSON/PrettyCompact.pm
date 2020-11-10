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

# Internal encoders can't be cloned
# so we basicaly create a new instance but inheriting
# the settings (that may have been initialized from defaults)
# and then, the constructor recreates encoders with those settings.
# If you mutated the encoder underneath us, your mutations will be
# lost.
sub clone {
    my ( $old, @args ) = @_;
    my (%params) = ref $args[0] ? %{ $args[0] } : @args;
    my (%config);
    for ( keys %{$old} ) {
        next if $_ =~ /^_/;
        $config{$_} = exists $params{$_} ? $params{$_} : $old->{$_};
    }
    ( ref $old )->new( \%config );
}
sub encode { $_[0]->_encode_width( $_[1], $_[0]->{width} ) }

sub _encode_array_width {
    my ( $self, $width, @values ) = ( $_[0], $_[2], @{ $_[1] } );
    return "[]" unless @values;

    my $space =
      $self->{width_is_local} ? $self->{width} : $width - $self->{indent};
    my $inline_comma = ( $self->{space_after} ? q[, ] : q[,] );
    my $comma_size   = length $inline_comma;

    my (@entries);
    for my $value (@values) {
        my $entry = $self->_encode_width( $value, $space );
        $entry =~ s/\s*\Z//ms;

        if (    @entries
            and $self->{fold_arrays}
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
          map { " " x $self->{indent} . $_ } split /\n/, $entry;
    }
    return "[\n" . ( join qq[,\n], @entries ) . "\n]";
}

sub _encode_hash_width {
    my ( $self, $width, %pairs ) = ( $_[0], $_[2], %{ $_[1] } );
    my (@keys) = $self->{canonical} ? sort keys %pairs : keys %pairs;
    return "{}" unless @keys;

    my $inline_comma = ( $self->{space_after} ? q[, ] : q[,] );
    my $comma_size   = length $inline_comma;

    my (@entries);
    for my $key (@keys) {
        my $label = $self->{_variable_encoder}->encode($key);
        $label .= " " if $self->{space_before};
        $label .= ":";
        $label .= " " if $self->{space_after};

        my $space =
            $self->{width_is_local}
          ? $self->{width}
          : $width - length($label) - $self->{indent};
        my $entry = $label . $self->_encode_width( $pairs{$key}, $space );
        $entry =~ s/\s*\Z//ms;

        if (    @entries
            and $self->{fold_hashes}
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
          map { " " x $self->{indent} . $_ } split /\n/, $entry;
    }
    return "{\n" . ( join qq[,\n], @entries ) . "\n}";
}

sub _encode_width {
    my ( $self, $value, $width ) = @_;
    if ( not ref $value or 'JSON::PP::Boolean' eq ref $value ) {
        return $self->{_variable_encoder}->encode($value);
    }
    my $test_encoding = $self->{_encoder}->encode($value);
    return $test_encoding if $width >= length $test_encoding;
    return $self->_encode_hash_width( $value, $width )
      if 'HASH' eq ref $value;
    return $self->_encode_array_width( $value, $width )
      if 'ARRAY' eq ref $value;
    die "Can't encode ref type " . ref $value;
}
1;
