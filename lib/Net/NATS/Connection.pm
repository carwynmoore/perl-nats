package Net::NATS::Connection;

use Class::XSAccessor {
    constructors => [ '_new' ],
    accessors => [
        'socket_args',
        '_socket',
    ],
};

use IO::Socket::INET;

sub new {
    my $class = shift;
    my $self = $class->_new(@_);

    $self->socket_args->{Proto} = 'tcp';

    my $socket = IO::Socket::INET->new(%{$self->socket_args})
        or return;
    $self->_socket($socket);

    return $self;
}

sub upgrade {
    my $self = shift;

    unless ($IO::Socket::SSL::VERSION) {
        eval { require IO::Socket::SSL };
        die $@ if $@;
    }

    my $socket = IO::Socket::SSL->start_SSL($self->_socket, %{$self->socket_args})
        or return;

    $self->_socket($socket);
}

1;
