# frozen_string_literal: true

# Verify that redis_preload behaves like AR .includes after relation reset:
# preload metadata survives reset, and the context is re-attached on every load.
RSpec.describe "relation reset behavior" do
  # ---------------------------------------------------------------------------
  # Reference: AR .includes after reset
  # ---------------------------------------------------------------------------
  describe "AR .includes (reference behavior)" do
    let!(:user) { User.create!(name: "alice") }
    let!(:a1) { Article.create!(user: user, title: "first") }

    it "re-preloads associations after reset + load" do
      rel = User.includes(:articles).where(id: user.id)
      rel.load
      expect(rel.first.articles.map(&:id)).to contain_exactly(a1.id)

      a2 = Article.create!(user: user, title: "second")
      rel.reset
      rel.load

      expect(rel.first.articles.map(&:id)).to contain_exactly(a1.id, a2.id)
    end
  end

  # ---------------------------------------------------------------------------
  # redis_preload after reset — should match AR .includes behavior
  # ---------------------------------------------------------------------------
  describe "redis_preload after reset" do
    let!(:w1) { Widget.create!(name: "w1") }

    before { w1.view_count.increment(10) }

    it "attaches preload context on first load" do
      rel = Widget.where(id: w1.id).redis_preload(:view_count)
      rel.load

      expect(rel.first.view_count.instance_variable_defined?(:@preload_context)).to be true
    end

    it "re-attaches preload context after reset + load" do
      rel = Widget.where(id: w1.id).redis_preload(:view_count)
      rel.load
      rel.reset
      rel.load

      expect(rel.first.view_count.instance_variable_defined?(:@preload_context)).to be true
    end

    it "uses batched mget on first load" do
      redis = Redis::Objects.redis
      allow(redis).to receive(:mget).and_call_original

      rel = Widget.where(id: w1.id).redis_preload(:view_count)
      rel.load
      rel.first.view_count.value

      expect(redis).to have_received(:mget).once
    end

    it "uses batched mget after reset + load" do
      rel = Widget.where(id: w1.id).redis_preload(:view_count)
      rel.load
      rel.reset

      redis = Redis::Objects.redis
      allow(redis).to receive(:mget).and_call_original

      rel.load
      rel.first.view_count.value

      expect(redis).to have_received(:mget).once
    end

    it "picks up Redis value changes made between reset and reload" do
      rel = Widget.where(id: w1.id).redis_preload(:view_count)
      rel.load
      expect(rel.first.view_count.value).to eq(10)

      w1.view_count.increment(5)
      rel.reset
      rel.load

      expect(rel.first.view_count.value).to eq(15)
    end
  end
end
