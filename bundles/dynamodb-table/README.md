# DynamoDB Table

One table for one app, billed per request with no capacity to manage.

## Access

The table publishes two IAM policies, **read** and **read-write**. A connected function attaches one to its own role, so permissions to the table are defined in one place and every consumer gets the same set. Read covers get, batch get, query and scan. Read-write adds put, update, delete and batch write.

## Keys

The partition key, and sort key if any, are fixed once the table exists. Generic names (`pk`, `sk`) with values like `USER#123` let one table hold several kinds of items, which is usually cheaper and simpler than one table per entity.

## Expiring items

Set **Expire items by attribute** to the name of a Number attribute that holds a Unix timestamp in seconds. DynamoDB deletes items some time after that moment, usually within a few days, at no charge.

## Recovery

With **Point-in-time recovery** on, the table can be restored to any second in the last 35 days, into a new table. Without it, deleted data is gone.
