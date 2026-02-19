# frozen_string_literal: true

RSpec.describe Redis::Objects::Preloadable::RelationExtension do
  let!(:w1) { Widget.create!(name: "w1") }

  describe "#redis_preload" do
    it "returns an ActiveRecord::Relation" do
      relation = Widget.all.redis_preload(:view_count)
      expect(relation).to be_a(ActiveRecord::Relation)
    end

    it "preserves preload names through spawn" do
      relation = Widget.where(id: w1.id).redis_preload(:view_count, :tag_ids)
      expect(relation.redis_preload_names).to eq(%i[view_count tag_ids])
    end

    it "chains with other scopes" do
      relation = Widget.where(name: "w1").order(:id).redis_preload(:view_count).limit(5)
      expect(relation).to be_a(ActiveRecord::Relation)
    end
  end
end
