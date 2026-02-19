# frozen_string_literal: true

RSpec.describe "value preloading" do
  let!(:w1) { Widget.create!(name: "w1") }
  let!(:w2) { Widget.create!(name: "w2") }
  let!(:w3) { Widget.create!(name: "w3") }

  before do
    w1.last_seen.value = "2024-01-01"
    w2.last_seen.value = "2024-06-15"
    # w3 has no value set
  end

  it "preloads value objects via MGET" do
    records = Widget.where(id: [w1.id, w2.id, w3.id]).redis_preload(:last_seen).load

    expect(records.find { |r| r.id == w1.id }.last_seen.value).to eq("2024-01-01")
    expect(records.find { |r| r.id == w2.id }.last_seen.value).to eq("2024-06-15")
    expect(records.find { |r| r.id == w3.id }.last_seen.value).to be_nil
  end

  it "reports nil? correctly" do
    records = Widget.where(id: [w1.id, w3.id]).redis_preload(:last_seen).load

    loaded_w1 = records.find { |r| r.id == w1.id }
    loaded_w3 = records.find { |r| r.id == w3.id }

    expect(loaded_w1.last_seen.nil?).to be false
    expect(loaded_w3.last_seen.nil?).to be true
  end
end
