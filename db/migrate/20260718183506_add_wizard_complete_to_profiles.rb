class AddWizardCompleteToProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :profiles, :wizard_complete, :boolean, default: false, null: false
  end
end
