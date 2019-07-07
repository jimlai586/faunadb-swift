Great db, centering around json and networking. 
 
However its iOS client currently has some problems.

## Swift 3 is obsolete

it needs an update to Swift 5 and takes advantage of new language features.

## Uses semaphore lock for async operations

i'd prefer not to worry about locks, there are other ways to avoid nested callbacks

## Uses its own JSON implementation/mapping 

iOS application always comes equipped with dedicated JSON framework, it would be a lot simpler and consistent 

to use the same framework for all things JSON.

# My Approach 

## Update to Swift 5

## Use Promise with built-in Result type

eliminating locks, and it can later be upgraded with Combine framework

## Use MagicJSON, which I wrote

eliminating paths and segments, don't need intermediate types, you write queries like writing JSON.

## Example
```Swift 
create(RefV("Post"), ObjV(mj: ["data": ["test": 123]]))
```
where create:_: simply builds the rest of the JSON, you only need to fill in important parts.

it's easier to read, operate, and you can easily add your own function for common queries.

## Current Status

Tested a few simple queries successfully. 

You can send query using this client if you can construct all of the required JSON.

All of the built-in functions need to be re-written, and I haven't got time.


