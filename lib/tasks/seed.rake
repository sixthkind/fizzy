namespace :seed do
  desc "Seed customer data for a specific account (e.g., rails seed:customer 1234)"
  task :customer, [:tenant_id] => :environment do |t, args|
    raise "Please provide a tenant ID: rails seed:customer[1234]" unless args[:tenant_id]

    tenant_id = args[:tenant_id].to_i
    ApplicationRecord.current_tenant = tenant_id
    account = Account.sole
    Account::Seeder.new(account, User.active.first).seed!

    puts "✓ Seeded account #{account.name} (tenant: #{tenant_id})"
  end
end
