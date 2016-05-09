# NATS - Perl Client
A [Perl](http://www.perl.org) client for the [NATS messaging system](https://nats.io).

## Basic Usage

```perl

$client = Net::NATS::Client->new(uri => 'nats://localhost:4222');
$client->connect() or die;

# Simple Publisher
$client->publish('foo', 'Hello, World!');

# Simple Async Subscriber
$subscription = $client->subscribe('foo', sub {
    my ($message) = @_;
    printf('Received a message: %s\n', $message->payload);
});

# Process pending operations
$client->wait_for_op();

# Unsubscribe
$subscription->unsubscribe();

# Close connection
$client->close();
```


The MIT License (MIT)
=====================

Copyright © `2016` `Carwyn Moore`

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the “Software”), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
