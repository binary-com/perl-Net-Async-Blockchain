# NAME

Net::Async::Blockchain - base for blockchain subscription clients.

# SYNOPSIS

Objects of this type would not normally be constructed directly.

For blockchain clients see:
\- Net::Async::Blockchain::BTC
\- Net::Async::BLockchain::ETH

Which will use this class as base.

# DESCRIPTION

This module contains methods that are shared by the subscription clients.

## configure

Any additional configuration that is not described on [IO::Async::Notifier](https://metacpan.org/pod/IO%3A%3AAsync%3A%3ANotifier)
must be included and removed here.

- `subscription_url` Subscription URL it can be TCP for ZMQ and WS for the Websocket subscription
=item \* `subscription_timeout` Subscription connection timeout
=item \* `subscription_msg_timeout` Subscription interval between messages timeout
=item \* `blockchain_code` The blockchain code (eg: bitcoin, litecoin, ....)

## subscription\_response

Formate the subscription response message

- `$subscription_type` - A string of the subscription type (e.g: blocks)
- `$messgae`           - The recevied subscription message from the blockchain node

Returns a hash reference of:

- `blockchain_code`   - A string of the blockchain code (eg: bitcoin, litecoin, ....)
- `subscription_type` - A string of the subscription type (e.g: blocks)
- `message`           - The recevied subscription message from the blockchain node
