package Net::Async::Blockchain::Client::ZMQ;

use strict;
use warnings;

our $VERSION = '0.001';

=head1 NAME

Net::Async::Blockchain::Client::ZMQ - Async ZMQ Client.

=head1 SYNOPSIS

    my $loop = IO::Async::Loop->new();

    $loop->add(my $zmq_source = Ryu::Async->new);

    $loop->add(
        my $zmq_client = Net::Async::Blockchain::Client::ZMQ->new(
            source   => $zmq_source->source,
            endpoint => 'tpc://127.0.0.1:28332',
        ));

    $zmq_client->subscribe('rawtx')->each(sub{print shift->{hash}});

    $loop->run();

=head1 DESCRIPTION

client for the bitcoin ZMQ server

=over 4

=back

=cut

no indirect;

use ZMQ::LibZMQ3;
use ZMQ::Constants qw(ZMQ_RCVMORE ZMQ_SUB ZMQ_SUBSCRIBE ZMQ_RCVHWM ZMQ_FD ZMQ_DONTWAIT ZMQ_RCVTIMEO);
use IO::Async::Notifier;
use IO::Async::Handle;
use Socket;

use parent qw(IO::Async::Notifier);

use constant {
    DEFAULT_TIMEOUT => 100,
    # 1 hour (milliseconds)
    DEFAULT_MSG_TIMEOUT => 3600000,
    # https://github.com/lestrrat-p5/ZMQ/blob/master/ZMQ-Constants/lib/ZMQ/Constants.pm#L128
    ZMQ_CONNECT_TIMEOUT => 79,
};

# Since the connect timeout is not present in the LIbZMQ3 module
# we need to add it manually
ZMQ::Constants::set_sockopt_type("int" => ZMQ_CONNECT_TIMEOUT);

=head2 source

Create an L<Ryu::Source> instance, if it is already defined just return
the object

=over 4

=back

L<Ryu::Source>

=cut

sub source : method {
    my ($self) = @_;
    return $self->{source} //= do {
        $self->add_child(my $source = Ryu::Async->new);
        $self->{source} = $source->source;
        return $self->{source};
    }
}

=head2 endpoint

TCP ZMQ endpoint

=over 4

=back

URL containing the port if needed, in case of DNS this will
be resolved to an IP.

=cut

sub endpoint : method { shift->{endpoint} }

=head2 timeout

Timeout time for connection

=over 4

=back

Integer time in milliseconds

=cut

sub timeout : method { shift->{timeout} // DEFAULT_TIMEOUT }

=head2 msg_timeout

Timeout time for received messages, this is applied when we have a bigger
duration interval between the messages.

=over 4

=back

Integer time in milliseconds

=cut

sub msg_timeout : method { shift->{msg_timeout} // DEFAULT_MSG_TIMEOUT }

=head2 configure

Any additional configuration that is not described on L<IO::ASYNC::Notifier>
must be included and removed here.

If this class receive a DNS as endpoint this will be resolved on this method
to an IP address.

=over 4

=item * C<endpoint>

=item * C<source> L<Ryu::Source>

=back

=cut

sub configure {
    my ($self, %params) = @_;

    for my $k (qw(endpoint source timeout msg_timeout)) {
        $self->{$k} = delete $params{$k} if exists $params{$k};
    }

    $self->SUPER::configure(%params);

    my $uri  = URI->new($self->endpoint);
    my $host = $uri->host;

    # Resolve DNS if needed
    if ($host !~ /(\d+(\.|$)){4}/) {
        my @addresses = gethostbyname($host) or die "Can't resolve @{[$host]}: $!";
        @addresses = map { inet_ntoa($_) } @addresses[4 .. $#addresses];

        my $address = $addresses[0];

        $self->{endpoint} = $self->{endpoint} =~ s/$host/$address/r;
    }

}

=head2 subscribe

Connect to the ZMQ server and start the subscription

=over 4

=item * C<subscription> subscription string name

=back

L<Ryu::Source>

=cut

sub subscribe {
    my ($self, $subscription) = @_;

    # one thread
    my $ctxt = zmq_ctx_new(1);
    die "zmq_ctc_new failed with $!" unless $ctxt;

    my $socket = zmq_socket($ctxt, ZMQ_SUB);

    # zmq_setsockopt_string is not exported
    ZMQ::LibZMQ3::zmq_setsockopt_string($socket, ZMQ_SUBSCRIBE, $subscription);

    my $connect_response = zmq_connect($socket, $self->endpoint);
    die "zmq_connect failed with $!" unless $connect_response == 0;

    # set connection timeout
    zmq_setsockopt($socket, ZMQ_CONNECT_TIMEOUT, $self->timeout);

    # receive message timeout
    zmq_setsockopt($socket, ZMQ_RCVTIMEO, $self->msg_timeout);

    # create a reader for IO::Async::Handle using the ZMQ socket file descriptor
    my $fd = zmq_getsockopt($socket, ZMQ_FD);
    open(my $io, '<&', $fd) or die "Unable to open file descriptor";

    $self->add_child(
        my $handle = IO::Async::Handle->new(
            read_handle => $io,
            on_closed   => sub {
                close($io) or die "Unable to close file descriptor";
            },
            on_read_ready => sub {
                while (my @msg = $self->_recv_multipart($socket)) {
                    my $hex = unpack('H*', zmq_msg_data($msg[1]));
                    $self->source->emit($hex);
                }
            }));

    return $self->source;
}

=head2 _recv_multipart

Since each response is partial we need to join them

=over 4

=item * C<subscription> subscription string name

=back

Multipart response array

=cut

sub _recv_multipart {
    my ($self, $socket) = @_;

    my @multipart;

    push @multipart, zmq_recvmsg($socket, ZMQ_DONTWAIT);
    while (zmq_getsockopt($socket, ZMQ_RCVMORE)) {
        push @multipart, zmq_recvmsg($socket, ZMQ_DONTWAIT);
    }

    return @multipart;
}

1;

