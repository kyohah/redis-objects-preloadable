# frozen_string_literal: true

RSpec.describe Redis::Objects::Preloadable::PreloadContext do
  let!(:w1) { Widget.create!(name: "w1") }
  let!(:w2) { Widget.create!(name: "w2") }

  before do
    w1.view_count.increment(10)
    w2.view_count.increment(20)
  end

  describe "#resolve!" do
    it "resolves only once even when called multiple times" do
      context = described_class.new([w1, w2], [:view_count])

      redis = Redis::Objects.redis
      expect(redis).to receive(:mget).once.and_call_original

      context.resolve!
      context.resolve!
    end

    it "handles empty records" do
      context = described_class.new([], [:view_count])
      expect { context.resolve! }.not_to raise_error
    end

    it "separates MGET types from pipeline types" do
      w1.recent_ids << "1"

      records = Widget.where(id: [w1.id, w2.id]).redis_preload(:view_count, :recent_ids).load

      loaded_w1 = records.find { |r| r.id == w1.id }
      expect(loaded_w1.view_count.value).to eq(10)
      expect(loaded_w1.recent_ids.value).to eq(["1"])
    end
  end
end
