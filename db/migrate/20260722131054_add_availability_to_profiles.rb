class AddAvailabilityToProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :profiles, :availability, :integer
  end
end
