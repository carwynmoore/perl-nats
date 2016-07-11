package Net::NATS::Connection;
use strict;

use Class::XSAccessor {
    constructors => [ '_new' ],
    accessors => [
        'socket_args',
        '_socket',
    ],
    lvalue_accessors => [
        'buffer',
        'eobuf',
        'eof',
        'error',
    ],
};

use IO::Socket::INET;
use Errno 'EWOULDBLOCK';

sub new {
    my $class = shift;
    my $self = $class->_new(@_);

    $self->socket_args->{Proto} = 'tcp';

    my $socket = IO::Socket::INET->new(%{$self->socket_args})
        or return;
    $self->_socket($socket);
    $socket->blocking(0);
    $self->flush();

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
    $socket->blocking(0);
    $self->flush();
}

# clear out the buffered data
sub flush {
    my $self = shift;

    $self->buffer = '';
    $self->eobuf = 0;
    $self->eof = 0;
    $self->error = '';
}

# test if we have data on the handle, with optional timeout.
sub can_read {
  my $self = shift;

  return IO::Select->new($self->_socket)->can_read(@_);
}


# implement non-blocking getline() function by managing our own data buffer
# based on sample code from "Network Programming with Perl" by L.D. Stein.

# $bytes = $self->nb_getline($data);
# data is stored in $data, returns number of bytes on success
# returns undef on error and sets $self->error, $data has any partial read
# returns 0 on EOF, $data has partial read
# returns 0E0 if would block (ie, not a full line read), data is unchanged.

sub nb_getline {
  my $self = shift;

  return 0 if $self->eof;       # previous read reached EOF
  return undef if $self->error; # previous read encountered error

  # look up position of EOL in the buffer
  my $idx = index($self->buffer, $/);
  if ($idx < 0) {
    # EOL was not found, so suck in more data if we can
    $self->eobuf = length $self->buffer;
    # append to our buffer from the file handle if any data is there.
    my $count = sysread($self->_socket,$self->buffer,1024,$self->eobuf);

    if (!defined $count) {
      return '0E0' if $! == EWOULDBLOCK; # we handle this error

      $self->error = $!;               # remember the error for later
      $_[0] = $self->buffer;           # return whatever we read
      return length($_[0]);
    }
    elsif ($count == 0) { # EOF
      $self->eof = 1;           # remember for later
      $_[0] = $self->buffer;    # return whatever we read
      return length($_[0]);
    }
    else {
      # look for EOL again in the newly read data
      $idx = index($self->buffer, $/, $self->eobuf);
      # if not found, pretend this was EWOULDBLOCK
      if ($idx < 0) {
        print "g simulating WOULDBLOCK\n";
        $self->eobuf = length $self->buffer;
        return '0E0';
      }
    }
  }

  # we successfully read what we needed up to a new line
  $_[0] = substr($self->buffer,0,$idx + length($/));
  substr($self->buffer,0,$idx + length($/)) = '';
  $self->eobuf = length $self->buffer;
  return length($_[0]);
}


# implement read() function upon our data buffer.
sub nb_read {
  my $self = shift;
  my $length = $_[1];

  return 0 if $self->eof;       # previous read reached EOF
  return undef if $self->error; # previous read encountered error

  # do we have enough data?
  if (length $self->buffer < $length) {
    # not enough, so suck in more data if we can
    $self->eobuf = length $self->buffer;
    # append to our buffer from the file handle if any data is there.
    my $count = sysread($self->_socket,$self->buffer,1024,$self->eobuf);

    if (!defined $count) {
      return '0E0' if $! == EWOULDBLOCK; # we handle this error

      $self->error = $!;                 # remember the error for later
      $_[0] = $self->buffer;             # return whatever we read
      return length($_[0]);
    }
    elsif ($count == 0) { # EOF
      $self->eof = 1;           # remember for later
      $_[0] = $self->buffer;    # return whatever we read
      return length($_[0]);
    }
    else {
      # check length again
      $self->eobuf = length $self->buffer;
      # if not, pretend this was EWOULDBLOCK
      if ($self->eobuf < $length) {
        return '0E0';
      }
    }
  }

  # we successfully read what we needed
  $_[0] = substr($self->buffer,0,$length);
  substr($self->buffer,0,$length) = '';
  $self->eobuf = length $self->buffer;
  return length($_[0]);
}

1;
