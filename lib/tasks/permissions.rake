namespace :permissions do
  desc "Sync the Permission catalog and relation grants from the SocialStream configuration"
  task sync: :environment do
    result = PermissionSync.new.call

    puts "PermissionSync complete:"
    puts "  permissions created:       #{result[:permissions]}"
    puts "  single-relation grants:    #{result[:single_grants]}"
    puts "  custom-relation grants:    #{result[:custom_grants]}"
  end
end
