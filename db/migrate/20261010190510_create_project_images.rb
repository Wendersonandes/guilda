class CreateProjectImages < ActiveRecord::Migration[8.1]
  def change
    create_table :project_images do |t|
      t.references :project, null: false, foreign_key: { on_delete: :cascade }
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :project_images, [ :project_id, :position ]
  end
end
