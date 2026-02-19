# frozen_string_literal: true

RSpec.describe "list preloading" do
  let!(:w1) { Widget.create!(name: "w1") }
  let!(:w2) { Widget.create!(name: "w2") }
  let!(:w3) { Widget.create!(name: "w3") }

  before do
    w1.recent_ids << "100"
    w1.recent_ids << "101"
    w2.recent_ids << "200"
    # w3 has no list entries
  end

  it "preloads list values via pipeline" do
    records = Widget.where(id: [w1.id, w2.id, w3.id]).redis_preload(:recent_ids).load

    expect(records.find { |r| r.id == w1.id }.recent_ids.value).to contain_exactly("100", "101")
    expect(records.find { |r| r.id == w2.id }.recent_ids.value).to eq(["200"])
    expect(records.find { |r| r.id == w3.id }.recent_ids.value).to eq([])
  end

  it "supports [] access" do
    records = Widget.where(id: w1.id).redis_preload(:recent_ids).load
    list = records.first.recent_ids

    expect(list[0]).to eq("100")
    expect(list[1]).to eq("101")
  end

  it "supports length and empty?" do
    records = Widget.where(id: [w1.id, w3.id]).redis_preload(:recent_ids).load

    loaded_w1 = records.find { |r| r.id == w1.id }
    loaded_w3 = records.find { |r| r.id == w3.id }

    expect(loaded_w1.recent_ids.length).to eq(2)
    expect(loaded_w1.recent_ids.empty?).to be false
    expect(loaded_w3.recent_ids.length).to eq(0)
    expect(loaded_w3.recent_ids.empty?).to be true
  end
end
