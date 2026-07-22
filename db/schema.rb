# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_22_131054) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "activities", force: :cascade do |t|
    t.bigint "author_id", null: false
    t.datetime "created_at", null: false
    t.bigint "owner_id", null: false
    t.bigint "parent_id"
    t.datetime "updated_at", null: false
    t.bigint "user_author_id"
    t.integer "verb", null: false
    t.index ["author_id"], name: "index_activities_on_author_id"
    t.index ["created_at"], name: "index_activities_on_created_at"
    t.index ["owner_id"], name: "index_activities_on_owner_id"
    t.index ["parent_id"], name: "index_activities_on_parent_id"
    t.index ["user_author_id"], name: "index_activities_on_user_author_id"
    t.index ["verb"], name: "index_activities_on_verb"
  end

  create_table "activity_actions", force: :cascade do |t|
    t.bigint "activity_object_id", null: false
    t.bigint "actor_id", null: false
    t.datetime "created_at", null: false
    t.boolean "follow", default: false
    t.datetime "updated_at", null: false
    t.index ["activity_object_id"], name: "index_activity_actions_on_activity_object_id"
    t.index ["actor_id", "activity_object_id"], name: "index_activity_actions_on_actor_id_and_activity_object_id", unique: true
  end

  create_table "activity_object_activities", force: :cascade do |t|
    t.bigint "activity_id", null: false
    t.bigint "activity_object_id", null: false
    t.datetime "created_at", null: false
    t.string "object_type", default: "object"
    t.datetime "updated_at", null: false
    t.index ["activity_id"], name: "index_activity_object_activities_on_activity_id"
    t.index ["activity_object_id"], name: "index_activity_object_activities_on_activity_object_id"
  end

  create_table "activity_object_audiences", force: :cascade do |t|
    t.bigint "activity_object_id", null: false
    t.datetime "created_at", null: false
    t.bigint "relation_id", null: false
    t.datetime "updated_at", null: false
    t.index ["activity_object_id", "relation_id"], name: "index_ao_audiences_on_ao_id_and_relation_id", unique: true
    t.index ["relation_id"], name: "index_activity_object_audiences_on_relation_id"
  end

  create_table "activity_objects", force: :cascade do |t|
    t.bigint "author_id"
    t.integer "comment_count", default: 0
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "follower_count", default: 0
    t.integer "like_count", default: 0
    t.bigint "objectable_id", null: false
    t.string "objectable_type", null: false
    t.bigint "owner_id"
    t.jsonb "payload", default: {}
    t.string "title", default: ""
    t.datetime "updated_at", null: false
    t.bigint "user_author_id"
    t.integer "visit_count", default: 0
    t.index ["author_id"], name: "index_activity_objects_on_author_id"
    t.index ["objectable_type", "objectable_id"], name: "index_activity_objects_on_objectable_type_and_objectable_id", unique: true
    t.index ["owner_id"], name: "index_activity_objects_on_owner_id"
    t.index ["user_author_id"], name: "index_activity_objects_on_user_author_id"
  end

  create_table "actors", force: :cascade do |t|
    t.bigint "activity_object_id"
    t.bigint "actorable_id", null: false
    t.string "actorable_type", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "email"
    t.string "name", null: false
    t.jsonb "notification_settings", default: {}
    t.integer "sent_contacts_count", default: 0, null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["activity_object_id"], name: "index_actors_on_activity_object_id"
    t.index ["actorable_type", "actorable_id"], name: "index_actors_on_actorable_type_and_actorable_id", unique: true
    t.index ["slug"], name: "index_actors_on_slug", unique: true
  end

  create_table "audiences", force: :cascade do |t|
    t.bigint "activity_id", null: false
    t.datetime "created_at", null: false
    t.bigint "relation_id", null: false
    t.datetime "updated_at", null: false
    t.index ["activity_id", "relation_id"], name: "index_audiences_on_activity_id_and_relation_id", unique: true
    t.index ["relation_id"], name: "index_audiences_on_relation_id"
  end

  create_table "comments", force: :cascade do |t|
    t.string "body_html"
    t.decimal "confidence", precision: 20, scale: 19, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.boolean "deleted", default: false, null: false
    t.integer "depth", default: 0, null: false
    t.datetime "last_edited_at"
    t.boolean "moderated", default: false, null: false
    t.text "moderated_reason"
    t.integer "reply_count", default: 0, null: false
    t.integer "score", default: 1, null: false
    t.string "short_id", null: false
    t.datetime "updated_at", null: false
    t.index ["short_id"], name: "index_comments_on_short_id", unique: true
  end

  create_table "contacts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "inverse_id"
    t.bigint "receiver_id", null: false
    t.bigint "sender_id", null: false
    t.integer "ties_count", default: 0
    t.datetime "updated_at", null: false
    t.index ["inverse_id"], name: "index_contacts_on_inverse_id"
    t.index ["receiver_id"], name: "index_contacts_on_receiver_id"
    t.index ["sender_id", "receiver_id"], name: "index_contacts_on_sender_id_and_receiver_id", unique: true
  end

  create_table "flags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "note"
    t.string "reason", null: false
    t.datetime "updated_at", null: false
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.datetime "created_at"
    t.string "scope"
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_type", "sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_type_and_sluggable_id"
  end

  create_table "groups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "privacy", default: 0, null: false
    t.datetime "updated_at", null: false
  end

  create_table "mentions", force: :cascade do |t|
    t.bigint "activity_object_id", null: false
    t.bigint "actor_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["activity_object_id", "actor_id"], name: "index_mentions_on_activity_object_id_and_actor_id", unique: true
    t.index ["activity_object_id"], name: "index_mentions_on_activity_object_id"
    t.index ["actor_id"], name: "index_mentions_on_actor_id"
  end

  create_table "noticed_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "notifications_count"
    t.jsonb "params"
    t.bigint "record_id"
    t.string "record_type"
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id"], name: "index_noticed_events_on_record"
  end

  create_table "noticed_notifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.datetime "read_at", precision: nil
    t.bigint "recipient_id", null: false
    t.string "recipient_type", null: false
    t.datetime "seen_at", precision: nil
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_noticed_notifications_on_event_id"
    t.index ["recipient_type", "recipient_id"], name: "index_noticed_notifications_on_recipient"
  end

  create_table "permissions", force: :cascade do |t|
    t.integer "action", null: false
    t.datetime "created_at", null: false
    t.integer "object"
    t.datetime "updated_at", null: false
    t.index ["action", "object"], name: "index_permissions_on_action_and_object", unique: true
  end

  create_table "posts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "profiles", force: :cascade do |t|
    t.string "address"
    t.integer "availability"
    t.date "birthday"
    t.string "city"
    t.string "country"
    t.datetime "created_at", null: false
    t.string "mobile"
    t.string "organization"
    t.string "phone"
    t.string "state"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "website"
    t.boolean "wizard_complete", default: false, null: false
    t.string "zipcode"
    t.index ["user_id"], name: "index_profiles_on_user_id"
  end

  create_table "relation_permissions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "permission_id", null: false
    t.bigint "relation_id", null: false
    t.datetime "updated_at", null: false
    t.index ["relation_id", "permission_id"], name: "index_relation_permissions_on_relation_id_and_permission_id", unique: true
  end

  create_table "relations", force: :cascade do |t|
    t.bigint "actor_id"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "parent_id"
    t.string "receiver_type"
    t.string "sender_type"
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_relations_on_actor_id"
    t.index ["parent_id"], name: "index_relations_on_parent_id"
  end

  create_table "sites", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "taggings", force: :cascade do |t|
    t.string "context", limit: 128
    t.datetime "created_at", precision: nil
    t.bigint "tag_id"
    t.bigint "taggable_id"
    t.string "taggable_type"
    t.bigint "tagger_id"
    t.string "tagger_type"
    t.string "tenant", limit: 128
    t.index ["context"], name: "index_taggings_on_context"
    t.index ["tag_id", "taggable_id", "taggable_type", "context", "tagger_id", "tagger_type"], name: "taggings_idx", unique: true
    t.index ["tag_id"], name: "index_taggings_on_tag_id"
    t.index ["taggable_id", "taggable_type", "context"], name: "taggings_taggable_context_idx"
    t.index ["taggable_id", "taggable_type", "tagger_id", "context"], name: "taggings_idy"
    t.index ["taggable_id"], name: "index_taggings_on_taggable_id"
    t.index ["taggable_type", "taggable_id"], name: "index_taggings_on_taggable_type_and_taggable_id"
    t.index ["taggable_type"], name: "index_taggings_on_taggable_type"
    t.index ["tagger_id", "tagger_type"], name: "index_taggings_on_tagger_id_and_tagger_type"
    t.index ["tagger_id"], name: "index_taggings_on_tagger_id"
    t.index ["tagger_type", "tagger_id"], name: "index_taggings_on_tagger_type_and_tagger_id"
    t.index ["tenant"], name: "index_taggings_on_tenant"
  end

  create_table "tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.integer "taggings_count", default: 0
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
  end

  create_table "ties", force: :cascade do |t|
    t.bigint "contact_id", null: false
    t.datetime "created_at", null: false
    t.bigint "relation_id", null: false
    t.datetime "updated_at", null: false
    t.index ["contact_id", "relation_id"], name: "index_ties_on_contact_id_and_relation_id", unique: true
    t.index ["relation_id"], name: "index_ties_on_relation_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "current_profile_id"
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["current_profile_id"], name: "index_users_on_current_profile_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "activities", "activities", column: "parent_id", on_delete: :nullify
  add_foreign_key "activities", "actors", column: "author_id", on_delete: :restrict
  add_foreign_key "activities", "actors", column: "owner_id", on_delete: :restrict
  add_foreign_key "activities", "users", column: "user_author_id", on_delete: :restrict
  add_foreign_key "activity_actions", "activity_objects", on_delete: :restrict
  add_foreign_key "activity_actions", "actors", on_delete: :restrict
  add_foreign_key "activity_object_activities", "activities", on_delete: :cascade
  add_foreign_key "activity_object_activities", "activity_objects", on_delete: :cascade
  add_foreign_key "activity_object_audiences", "activity_objects", on_delete: :cascade
  add_foreign_key "activity_object_audiences", "relations", on_delete: :cascade
  add_foreign_key "activity_objects", "actors", column: "author_id", on_delete: :restrict
  add_foreign_key "activity_objects", "actors", column: "owner_id", on_delete: :restrict
  add_foreign_key "activity_objects", "users", column: "user_author_id", on_delete: :restrict
  add_foreign_key "actors", "activity_objects", on_delete: :nullify
  add_foreign_key "audiences", "activities", on_delete: :cascade
  add_foreign_key "audiences", "relations", on_delete: :cascade
  add_foreign_key "contacts", "actors", column: "receiver_id", on_delete: :restrict
  add_foreign_key "contacts", "actors", column: "sender_id", on_delete: :restrict
  add_foreign_key "contacts", "contacts", column: "inverse_id", on_delete: :nullify
  add_foreign_key "mentions", "activity_objects", on_delete: :cascade
  add_foreign_key "mentions", "actors", on_delete: :cascade
  add_foreign_key "profiles", "users", on_delete: :restrict
  add_foreign_key "relation_permissions", "permissions", on_delete: :cascade
  add_foreign_key "relation_permissions", "relations", on_delete: :cascade
  add_foreign_key "relations", "actors", on_delete: :restrict
  add_foreign_key "relations", "relations", column: "parent_id", on_delete: :nullify
  add_foreign_key "taggings", "tags"
  add_foreign_key "ties", "contacts", on_delete: :restrict
  add_foreign_key "ties", "relations", on_delete: :restrict
  add_foreign_key "users", "actors", column: "current_profile_id", on_delete: :nullify
end
