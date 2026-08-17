require 'rails_helper'

# Spree::UserBillAddressSyncDecorator の挙動を検証するスペック
#
# User の bill_address(請求先)が確定したタイミングで、
# User の first_name / last_name / phone / company を bill_address から同期することを確認する。
RSpec.describe Spree::UserBillAddressSyncDecorator, type: :model do
  describe "#sync_attributes_from_bill_address" do
    let!(:user) do
      # name や phone, company を空で作成したいので、明示的に nil で上書き
      create(:user, first_name: nil, last_name: nil, phone: nil, company: nil)
    end

    context "User の名前等が未入力の状態で、新しい配送先(ship_address)のみ設定した場合" do
      let(:ship_address) do
        build(:address,
              firstname: "贈り先太郎",
              lastname: "山田",
              phone: "090-0000-1111",
              company: "贈り先会社",
              user: user)
      end

      before do
        ship_address.save!
        user.update!(ship_address: ship_address)
      end

      it "User の first_name / last_name / phone / company は更新されない" do
        expect(user.reload.attributes).to include(
          "first_name" => nil,
          "last_name" => nil,
          "phone" => nil,
          "company" => nil
        )
      end
    end

    context "User の名前等が未入力の状態で、新しい請求先(bill_address)を設定した場合" do
      let(:bill_address) do
        build(:address,
              firstname: "本人花子",
              lastname: "鈴木",
              phone: "090-1234-5678",
              company: "本人会社",
              user: user)
      end

      before do
        bill_address.save!
        user.update!(bill_address: bill_address)
      end

      it "User の first_name / last_name / phone / company が請求先からコピーされる" do
        # 注: phone は User#set_phone / Address#remove_emoji_and_normalize により
        # ハイフン除去された形式で保存される
        expect(user.reload.attributes).to include(
          "first_name" => "本人花子",
          "last_name" => "鈴木",
          "phone" => "09012345678",
          "company" => "本人会社"
        )
      end
    end

    context "既に名前が入力されている User の bill_address を、別の名前の Address に変更した場合" do
      let!(:user) do
        create(:user,
               first_name: "既存太郎",
               last_name: "既存姓",
               phone: "090-9999-9999",
               company: "既存会社")
      end
      let(:bill_address) do
        build(:address,
              firstname: "新しい太郎",
              lastname: "新しい姓",
              phone: "090-1234-5678",
              company: "新しい会社",
              user: user)
      end

      before do
        bill_address.save!
        user.update!(bill_address: bill_address)
      end

      it "first_name / last_name / phone / company は上書きされない" do
        # 注: User.phone も create 時に User#set_phone でハイフンが除去された形式になる
        expect(user.reload.attributes).to include(
          "first_name" => "既存太郎",
          "last_name" => "既存姓",
          "phone" => "09099999999",
          "company" => "既存会社"
        )
      end
    end

    context "User.phone が既にあり、別 phone の Address を bill_address に設定した場合" do
      let!(:user) { create(:user, first_name: nil, last_name: nil, phone: "090-9999-9999", company: nil) }
      let(:bill_address) do
        build(:address,
              firstname: "本人",
              lastname: "姓",
              phone: "080-1111-2222",
              company: nil,
              user: user)
      end

      before do
        bill_address.save!
        user.update!(bill_address: bill_address)
      end

      it "User.phone は phone.presence の優先順位で上書きされない" do
        # 注: 元の "090-9999-9999" は User#set_phone で "09099999999" に正規化されている
        expect(user.reload.phone).to eq "09099999999"
      end
    end

    context "bill_address が nil から非nilに変わったとき(User#bill_address_id 変更時)以外は発火しない" do
      let!(:user) { create(:user, first_name: nil, last_name: nil) }
      let(:bill_address) do
        build(:address, firstname: "本人", lastname: "姓", user: user)
      end

      before do
        bill_address.save!
        user.update!(bill_address: bill_address)
        # bill_address はそのままに、無関係な属性のみ更新
        user.update!(updated_at: Time.current + 1.minute)
        # その後 bill_address の名前だけ書き換える
        bill_address.update!(firstname: "別人", lastname: "別姓")
        user.reload
      end

      it "bill_address_id が変わっていないので User の名前は再同期されない(初回同期時の値のまま)" do
        expect(user.attributes).to include(
          "first_name" => "本人",
          "last_name" => "姓"
        )
      end
    end
  end
end
