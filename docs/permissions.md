# Permissions

Authorization in Guilda is **database-first and data-driven**. Every decision is expressed as a
pair of *action* and *object* granted to a `Relation`, and resolved through the `Tie`s an actor
holds. This document describes the model, the role → capability matrix, the `Actor#can?` API,
and how to add or change capabilities.

> **Rule of thumb:** authorization is decided with `Actor#can?`. `has_relation_with?` / `has_role?`
> (and `role?`) are **identity** checks only — used for labels and business rules such as
> "the owner cannot leave the group", never to grant or deny an action on a resource.

## 1. Overview

```
Permission (action, object)
   │ has_many
RelationPermission (join)
   │
Relation (STI: Custom | Public | Follow | Owner | LocalAdmin | Reject)
   │ has_many
Tie ──── Contact (sender → receiver) ──── Actor
   │
Audience / ActivityObjectAudience ──── Activity / ActivityObject
```

- A `Permission` is the atomic unit: an `action` on an `object`.
- A `Relation` is the *type* of a connection (a role). It carries `Permission`s through
  `RelationPermission`.
- A `Tie` joins a `Contact` (sender → receiver) with a `Relation`. **Establishing a `Tie` grants
  the receiver the permissions of the relation.**
- `Audience` / `ActivityObjectAudience` attach `Relation`s to content, defining who can reach it.

## 2. Permission

`app/models/permission.rb` — pair with a unique index on `(action, object)` and a partial unique
index on `(action) WHERE object IS NULL`.

| action | meaning |
|---|---|
| `create` | create the object |
| `read` | read the object |
| `update` | update the object |
| `destroy` | delete the object |
| `follow` | subscribe to updates (`object: nil`) |
| `represent` | act on behalf of another actor (`object: nil`) |

| object | meaning |
|---|---|
| `activity` | activities/posts |
| `post` | post content |
| `comment` | comments |
| `group` | the group itself |
| `member` | group membership management |
| `admin` | admin panels access |
| `role` | role assignment (site) |

`object: nil` applies the action broadly (only `follow` and `represent` today).

## 3. Relations and roles

### System relations (`Relation::Single`, singletons via `.instance`)
- `Relation::Public` — `read activity` for everyone.
- `Relation::Follow` — `create/read activity`, `follow`.
- `Relation::Owner` — full permissions of the group (`available_permissions["group"]`); no
  contact activity.
- `Relation::LocalAdmin` — site permissions (`available_permissions["site"]`); no contact
  activity.
- `Relation::Reject` — no permissions; records a rejection.

### Custom relations (`Relation::Custom`)
Seeded per actor from `SocialStream.custom_relations` (`config/initializers/social_stream.rb`)
when the actor is created (`Relation::Custom.defaults_for`). Profiles get `friend`, `colleague`,
`acquaintance`; groups and the site get their role relations (below).

## 4. Role → capability matrix

`can?` / `has_permission?` outcomes per role, within the role's context (group or site).

### Group (`custom_relations["group"]` + `Relation::Owner`)

| capability | member | moderator | admin | owner |
|---|:--:|:--:|:--:|:--:|
| `read` activity / post / comment | ✓ | ✓ | ✓ | ✓ |
| `create` activity / post / comment | ✓ | ✓ | ✓ | ✓ |
| `update` activity / post / comment | – | ✓ | ✓ | ✓ |
| `destroy` activity / post / comment | – | – | ✓ | ✓ |
| `read group`, `read member` | ✓ | ✓ | ✓ | ✓ |
| `update group` | – | – | ✓ | ✓ |
| `create/update/destroy member` | – | – | ✓ | ✓ |
| `destroy group` | – | – | – | ✓ |
| `represent` | – | – | ✓ | ✓ |
| `follow` | – | – | – | ✓ |

Hierarchy is **linear**: `owner ⊇ admin ⊇ moderator ⊇ member ⊇ silenced`.
`leave group` is **not** a permission — it is a business rule in `GroupPolicy#leave?`
(any member role, except the owner).

### Site (`custom_relations["site"]`)

| capability | member | moderator | editor | admin | silenced | banned |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| `read` activity / post / comment | ✓ | ✓ | ✓ | ✓ | ✓ | – |
| `create` activity / post / comment | ✓ | – | ✓ | ✓ | – | – |
| `update` activity / post / comment | – | – | ✓ | ✓ | – | – |
| `destroy` activity / post / comment | – | ✓ | – | ✓ | – | – |
| `represent` | – | – | – | ✓ | – | – |
| `read admin` | – | – | – | ✓ | – | – |
| `update role` | – | – | – | ✓ | – | – |

The site hierarchy is **not** linear: `editor` has `create/update`, while `moderator` has
`destroy`. Do not assume a generic superset order for site roles.

## 5. API

```ruby
# The single authorization predicate (context defaults to the Site actor).
actor.can?(:update, :member, group_actor)
user.can?(:read, :admin)                 # delegates to user.current_profile

# Identity only (labels, business rules) — never for granting access.
actor.role?(:admin, Site.instance)       # alias: has_role?
actor.has_relation_with?(group_actor, "Owner")
```

`Actor#can?` resolves to `context.allow?(actor, action, object)`, i.e. it looks for a `Tie` from
the context actor to `actor` whose `Relation` grants the permission.

`has_permission?` is kept as a **deprecated alias** of `can?`; `has_role?` is an alias of `role?`.

## 6. Synchronization

`PermissionSync` (`app/services/permission_sync.rb`) and the rake task:

```sh
bin/rails permissions:sync
```

It is idempotent and does three things:
1. creates the missing `Permission` rows for every configured pair;
2. grants missing permissions to the system (`Relation::Single`) relations;
3. grants missing permissions to every actor's custom relations.

**Run it after changing `SocialStream.available_permissions` or `SocialStream.custom_relations`,
in every environment.** Existing `Tie`s only pick up new grants through this sync (the seed only
runs when an actor is created).

## 7. Adding a capability

1. Add the `[action, object]` pair to the relevant role(s) in
   `config/initializers/social_stream.rb` (and to `available_permissions[subject]` when it belongs
   to the subject's catalog).
2. Run `bin/rails permissions:sync`.
3. Use it through `can?` in the policy/controller/view.
4. Update the matrix in this document and in `test/permissions/capability_matrix_test.rb`.

## 8. Consistency tests

Under `test/permissions/`:
- `catalog_consistency_test.rb` — config ↔ `Permission` catalog; `Relation::Single::PERMISSIONS`
  ↔ grants; idempotency.
- `capability_matrix_test.rb` — asserts the matrices above (site + group).
- `call_site_coverage_test.rb` — every literal `can?(:action, :object)` pair used in `app/`
  exists in the catalog.
- `authorization_regression_test.rb` — forbids authorizing by role name in policies (allowlisted
  identity checks only).

See also the domain overview in [`AGENTS.md`](../AGENTS.md).
