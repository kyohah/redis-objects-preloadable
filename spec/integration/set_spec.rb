# frozen_string_literal: true

RSpec.describe "set preloading" do
  let!(:w1) { Widget.create!(name: "w1") }
  let!(:w2) { Widget.create!(name: "w2") }
  let!(:w3) { Widget.create!(name: "w3") }

  before do
    w1.tag_ids << "ruby"
    w1.tag_ids << "rails"
    w2.tag_ids << "python"
    # w3 has no set entries
  end

  it "preloads set members via pipeline" do
    records = Widget.where(id: [w1.id, w2.id, w3.id]).redis_preload(:tag_ids).load

    expect(records.find { |r| r.id == w1.id }.tag_ids.members).to contain_exactly("ruby", "rails")
    expect(records.find { |r| r.id == w2.id }.tag_ids.members).to eq(["python"])
    expect(records.find { |r| r.id == w3.id }.tag_ids.members).to eq([])
  end

  it "supports include?" do
    records = Widget.where(id: w1.id).redis_preload(:tag_ids).load
    set = records.first.tag_ids

    expect(set.include?("ruby")).to be true
    expect(set.include?("java")).to be false
  end

  it "supports length and empty?" do
    records = Widget.where(id: [w1.id, w3.id]).redis_preload(:tag_ids).load

    loaded_w1 = records.find { |r| r.id == w1.id }
    loaded_w3 = records.find { |r| r.id == w3.id }

    expect(loaded_w1.tag_ids.length).to eq(2)
    expect(loaded_w1.tag_ids.empty?).to be false
    expect(loaded_w3.tag_ids.length).to eq(0)
    expect(loaded_w3.tag_ids.empty?).to be true
  end
end
