# ToDo Lite Document Schema

(draft 1; 27 Aug 2013)

## Lists

* `type`: `list`
* `created_at`: _string_ (timestamp of when list was created)
* `title`: _string_ (user-visible title of list)
* `owner`: _string_ (doc ID of user who owns the list)
* `members`: _array[string]_ (doc IDs of other people with access to the list) **optional**

## Tasks

* `type`: `task`
* `created_at`: _string_ (timestamp of when task was created)
* `updated_at`: _string_ (timestamp of when task was last modified)
* `title`: _string_ (user-visible title of task)
* `checked`: _boolean_ (true if completed / checked-off) **optional**
* `list_id`: _string_ (doc ID of owning list)

## People / Users

* `type`: `profile`
* `_id`: _string_ (`p:` + user_id)
* `user_id`: _string_ (user ID assigned by Sync Gateway)
* `name`: _string_ (display name, e.g. `Clara Bow`)
* `email`: _string_ (email address) **optional**
* `facebook_id`: _string_ (Facebook user ID) **optional**

Note that the document ID (`_id`) is constrained to include the user ID.
This makes documents easy to look up by user ID, and prevents duplicate `user_id` values.
