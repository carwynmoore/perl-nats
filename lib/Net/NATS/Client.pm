package Net::NATS::Client;

our $VERSION = '0.000001';
$VERSION = eval $VERSION if $VERSION =~ /_/;

use Class::XSAccessor {
    constructors => [ '_new' ],
    accessors => [
        'connection',
        '_socket',
        'socket_args',
        'subscriptions',
        'uri',
    ],
    lvalue_accessors => [
        'current_sid',
        'message_count',
    ],
};

use strict;
use warnings;

use URI;
use JSON;

use Net::NATS::Connection;
use Net::NATS::Message;
use Net::NATS::ServerInfo;
use Net::NATS::ConnectInfo;
use Net::NATS::Subscription;

sub new {
    my $class = shift;

    my $self = $class->_new(@_);
    $self->socket_args({}) unless defined $self->socket_args;
    $self->subscriptions({});
    $self->current_sid = 0;
    $self->message_count = 0;

    return $self;
}

sub connect {
    my $self = shift;

    my $uri = URI->new($self->uri)
        or return;

    $self->socket_args->{PeerAddr} = $uri->host;
    $self->socket_args->{PeerPort} = $uri->port;

    my $connection = Net::NATS::Connection->new(socket_args => $self->socket_args)
        or return;
    $self->_socket($connection->_socket);

    # Get INFO line
    my ($op, @args) = $self->read_line;
    my $info = $self->handle_info(@args);

    my $connect_info = Net::NATS::ConnectInfo->new(
        lang    => 'perl',
        version => $VERSION,
    );

    if ($info->auth_required) {
        if (!defined $uri->password) {
            $connect_info->auth_token($uri->user);
        } else {
            $connect_info->user($uri->user);
            $connect_info->pass($uri->password);
        }
    }

    if ($info->ssl_required || $info->tls_required) {
        $connection->upgrade()
            or return;

        $self->_socket($connection->_socket);
    }

    my $connect = 'CONNECT ' . to_json($connect_info, { convert_blessed => 1});
    $self->send($connect);

    return 1;
}

sub subscribe {
    my $self = shift;

    my ($subject, $group, $callback);

    if (@_ == 2) {
        ($subject, $callback) = @_;
    } else {
        ($subject, $group, $callback) = @_;
    }

    my $sid = $self->next_sid;

    my $sub = "SUB $subject";
    $sub .= " $group" if defined $group;
    $sub .= " $sid";

    $self->send($sub);

    my $subscription = Net::NATS::Subscription->new(
        subject => $subject,
        group => $group,
        sid => $sid,
        callback => $callback,
        client => $self,
    );
    $self->subscriptions->{$sid} = $subscription;
    return $subscription;
}

sub unsubscribe {
    my $self = shift;
    my ($subscription, $max_msgs) = @_;

    $subscription->max_msgs = $max_msgs;
    my $sid = $subscription->sid;
    my $sub = "UNSUB $sid";
    $sub .= " $max_msgs" if defined $max_msgs;

    $self->send($sub);

    $self->_remove_subscription($subscription)
        unless defined $max_msgs;
}

sub publish {
    my $self = shift;
    my ($subject, $data, $reply_to) = @_;

    my $length = length($data);

    my $pub = "PUB $subject";
    $pub .= " $reply_to" if defined $reply_to;
    $pub .= " $length\r\n$data";

    $self->send($pub);
}

sub request {
    my ($self, $subject, $data, $callback) = @_;
    
    my $inbox = new_inbox();
    my $sub = $self->subscribe($inbox, $callback);
    $self->unsubscribe($sub, 1);
    $self->publish($subject, $data, $inbox);
}

sub _remove_subscription {
    my ($self, $subscription) = @_;

    delete $self->subscriptions->{$subscription->sid};
}

sub read {
    my ($self, $length) = @_;

    my $data;
    $self->_socket->read($data, $length)
        or return;
    $data =~ s/\r\n$//;
    return $data;
}

sub read_line {
    my ($self) = @_;
    my $line = $self->_socket->getline
        or return;
    $line =~ s/\r\n$//;
    print "[$line]\n";
    return split(' ', $line);
}

sub send {
    my $self = shift;
    my ($data) = @_;
    $self->_socket->print($data."\r\n");
}

sub handle_info {
    my $self = shift;
    my (@args) = @_;
    my $hash = decode_json($args[0]);
    return Net::NATS::ServerInfo->new(%$hash);
}

sub parse_msg {
    my $self = shift;

    my ($subject, $sid, $length, $reply_to);

    if (@_ == 3) {
        ($subject, $sid, $length) = @_;
    } else {
        ($subject, $sid, $reply_to, $length) = @_;
    }

    my $data = $self->read($length+2);
    my $subscription = $self->subscriptions->{$sid};
    my $message = Net::NATS::Message->new(
        subject      => $subject,
        sid          => $sid,
        reply_to     => $reply_to,
        length       => $length,
        data         => $data,
        subscription => $subscription,
    );

    $subscription->message_count++;
    $self->message_count++;

    if ($subscription->defined_max && $subscription->message_count >= $subscription->max_msgs) { 
        $self->_remove_subscription($subscription);
    }

    &{$subscription->callback}($message);
}

sub wait_for_op {
    my $self = shift;

    my ($op, @args) = $self->read_line;
    return unless defined $op;

    if ($op eq 'MSG') {
        my $message = parse_msg($self, @args);
    } elsif ($op eq 'PING') {
        $self->handle_ping;
    } elsif ($op eq 'PONG') {
    } elsif ($op eq '+OK') {
    } elsif ($op eq '-ERR') {
        return;
    }
    return 1;
}

sub handle_ping {
    my $self = shift;
    $self->send("PONG");
}

sub next_sid {
    my $self = shift;
    return ++$self->current_sid;
}

sub close {
    my $self = shift;
    $self->_socket->close;
}

sub new_inbox { sprintf("_INBOX.%08X%08X%06X", rand(2**32), rand(2**32), rand(2**24)); }

1;
