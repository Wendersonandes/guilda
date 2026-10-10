class AddInstagramToProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :profiles, :instagram, :string
  end
end
