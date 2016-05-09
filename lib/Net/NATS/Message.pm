package Net::NATS::Message;

use strict;
use warnings;

use Class::XSAccessor {
    constructor => 'new',
    accessors => [
        'subject',
        'sid',
        'reply_to',
        'length',
        'payload',
        'subscription',
    ],
};

1;
