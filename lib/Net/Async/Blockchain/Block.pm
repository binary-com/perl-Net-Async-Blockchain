package Net::Async::Blockchain::Block;

use strict;
use warnings;

our $VERSION = '0.001';

=head1 NAME

Net::Async::Blockchain::Block - Block abstraction.

=head1 SYNOPSIS

Objects of this type would not normally be constructed directly.

=head1 DESCRIPTION

Block abstraction

=over 4

=back

=cut

no indirect;

sub message_type { shift->{message_type} }
sub currency     { shift->{currency} }
sub number       { shift->{number} }

=head2 new

Create a new L<Net::Async::Blockchain::Block> instance

=over 4

=item * C<message_type> Message Type
=item * C<currency> Currency Symbol
=item * C<number> Block Number

=back

L<Net::Async::Blockchain::Block>

=cut

sub new {
    my ($class, %params) = @_;
    my $self = bless {}, $class;

    $self->{message_type} = 'block';

    foreach (qw(message_type number currency)) {
        $self->{$_} = delete $params{$_} if exists $params{$_};
    }

    die "Invalid block parameters" if keys %params;
    return $self;
}

=head2 clone

Clone the self object and the attribute values

=over 4

=back

new L<Net::Async::Blockchain::Block> based on self

=cut

sub clone {
    my ($self) = @_;
    return Net::Async::Blockchain::Block->new(%$self);
}

=head2 up

Add +1 to the block number

=over 4

=back

Returns self L<Net::Async::Blockchain::Block>

=cut

sub up {
    my ($self) = @_;
    $self->{number}++;
    return $self;
}

=head2 empty

set block number to empty

=over 4

=back

Returns self L<Net::Async::Blockchain::Block>

=cut

sub empty {
    my ($self) = @_;
    $self->{number} = undef;
    return $self;
}

1;
