module SocialStream
  mattr_accessor :available_permissions, :custom_relations, :system_relations, :suggested_models

  self.available_permissions = {
    "profile" => [
      [ "create", "activity" ],
      [ "read",   "activity" ],
      [ "follow", nil ],
      [ "represent", nil ],
      [ "create", "post" ],
      [ "read",   "post" ],
      [ "update", "post" ],
      [ "destroy", "post" ],
      [ "create", "comment" ],
      [ "read",   "comment" ],
      [ "update", "comment" ],
      [ "destroy", "comment" ]
    ],
    "group" => [
      [ "create", "activity" ],
      [ "read",   "activity" ],
      [ "update", "activity" ],
      [ "destroy", "activity" ],
      [ "follow", nil ],
      [ "represent", nil ],
      [ "create", "post" ],
      [ "read",   "post" ],
      [ "update", "post" ],
      [ "destroy", "post" ],
      [ "create", "comment" ],
      [ "read",   "comment" ],
      [ "update", "comment" ],
      [ "destroy", "comment" ]
    ],
    "site" => [
      [ "create", "activity" ],
      [ "read",   "activity" ],
      [ "update", "activity" ],
      [ "destroy", "activity" ],
      [ "follow", nil ],
      [ "represent", nil ],
      [ "create", "post" ],
      [ "read",   "post" ],
      [ "update", "post" ],
      [ "destroy", "post" ],
      [ "create", "comment" ],
      [ "read",   "comment" ],
      [ "update", "comment" ],
      [ "destroy", "comment" ]
    ]
  }.freeze

  self.custom_relations = {
    "profile" => {
      "friend" =>     { name: "Friend",     permissions: [ [ "create", "activity" ], [ "read",   "activity" ], [ "follow", nil ], [ "create", "post" ], [ "read", "post" ], [ "create", "comment" ], [ "read", "comment" ] ], receiver_type: "Profile" },
      "colleague" =>  { name: "Colleague",  permissions: [ [ "read",   "activity" ], [ "read",   "post" ],     [ "read",   "comment" ] ],                                                                     receiver_type: "Profile" },
      "acquaintance" => { name: "Acquaintance", permissions: [ [ "read",   "activity" ], [ "read",   "post" ],     [ "read",   "comment" ] ],                                                                 receiver_type: "Profile" }
    },
    "group" => {
      "admin" => {
        name: "Admin",
        permissions: [
          [ "create", "activity" ],
          [ "read",   "activity" ],
          [ "update",  "activity" ],
          [ "destroy", "activity" ],
          [ "represent", nil ],
          [ "create", "post" ],
          [ "read",   "post" ],
          [ "update",  "post" ],
          [ "destroy", "post" ],
          [ "create", "comment" ],
          [ "read",   "comment" ],
          [ "update",  "comment" ],
          [ "destroy", "comment" ]
        ],
        receiver_type: "Profile"
      },
      "moderator" => {
        name: "Moderator",
        permissions: [
          [ "create", "activity" ],
          [ "read",   "activity" ],
          [ "update", "activity" ],
          [ "create", "post" ],
          [ "read",   "post" ],
          [ "update", "post" ],
          [ "create", "comment" ],
          [ "read",   "comment" ],
          [ "update", "comment" ]
        ],
        receiver_type: "Profile"
      },
      "member" => {
        name: "Member",
        permissions: [
          [ "read", "activity" ],
          [ "create", "activity" ],
          [ "read", "post" ],
          [ "create", "post" ],
          [ "read", "comment" ],
          [ "create", "comment" ]
        ],
        receiver_type: "Profile"
      },
      "silenced" => {
        name: "Silenced",
        permissions: [
          [ "read", "activity" ],
          [ "read", "post" ],
          [ "read", "comment" ]
        ],
        receiver_type: "Profile"
      }
    },
    "site" => {
      "admin" => {
        name: "Admin",
        permissions: [
          [ "create", "activity" ],
          [ "read",   "activity" ],
          [ "update",  "activity" ],
          [ "destroy", "activity" ],
          [ "represent", nil ],
          [ "create", "post" ],
          [ "read",   "post" ],
          [ "update",  "post" ],
          [ "destroy", "post" ],
          [ "create", "comment" ],
          [ "read",   "comment" ],
          [ "update",  "comment" ],
          [ "destroy", "comment" ]
        ],
        receiver_type: "Profile"
      },
      "editor" => {
        name: "Editor",
        permissions: [
          [ "create", "activity" ],
          [ "read",   "activity" ],
          [ "update", "activity" ],
          [ "create", "post" ],
          [ "read",   "post" ],
          [ "update", "post" ],
          [ "create", "comment" ],
          [ "read",   "comment" ],
          [ "update", "comment" ]
        ],
        receiver_type: "Profile"
      },
      "moderator" => {
        name: "Moderator",
        permissions: [
          [ "read",   "activity" ],
          [ "destroy", "activity" ],
          [ "read",   "post" ],
          [ "destroy", "post" ],
          [ "read",   "comment" ],
          [ "destroy", "comment" ]
        ],
        receiver_type: "Profile"
      },
      "member" => {
        name: "Member",
        permissions: [
          [ "read",   "activity" ],
          [ "create", "activity" ],
          [ "read",   "post" ],
          [ "create", "post" ],
          [ "read",   "comment" ],
          [ "create", "comment" ]
        ],
        receiver_type: "Profile"
      },
      "silenced" => {
        name: "Silenced",
        permissions: [
          [ "read", "activity" ],
          [ "read", "post" ],
          [ "read", "comment" ]
        ],
        receiver_type: "Profile"
      },
      "banned" => {
        name: "Banned",
        permissions: [],
        receiver_type: "Profile"
      }
    }
  }.freeze

  self.system_relations = {}.freeze
  self.suggested_models = [ :profile ]
end
