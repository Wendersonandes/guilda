class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.references :profile, null: false, foreign_key: { on_delete: :cascade }
      t.string :title, null: false
      t.integer :visibility, null: false, default: 0
      t.integer :position, null: false, default: 0
      t.string :slug, null: false

      t.timestamps
    end

    add_index :projects, :slug, unique: true
    add_index :projects, [ :profile_id, :position ]
  end
end
