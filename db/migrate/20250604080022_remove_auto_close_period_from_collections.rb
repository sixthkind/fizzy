class RemoveAutoClosePeriodFromCollections < ActiveRecord::Migration[8.1]
  def change
    remove_column :collections, :auto_close_period
  end
end
