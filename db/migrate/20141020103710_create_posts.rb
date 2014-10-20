class CreatePosts < ActiveRecord::Migration
  def change
    create_table :posts do |t|
      t.references :users
      t.timestamps
    end
  end
end
