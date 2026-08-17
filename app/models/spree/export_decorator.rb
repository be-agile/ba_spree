module Spree
  module ExportDecorator
    # @gem-override spree_core-5.3.6/app/models/spree/export.rb#generate_csv
    # @see https://github.com/be-agile/giga-repeat/issues/1271
    # 標準CSVエクスポートは UTF-8(BOMなし)で出力するため、Windows/Excel や
    # 日本語エディタが Shift_JIS と誤判定して文字化けする。生成後のファイル先頭に
    # UTF-8 BOM を付与して、UTF-8 として正しく認識されるようにする。
    #
    # Spree 5.3 追従: メソッド本体(FormulaSanitizer 等)は super 経由で取り込むため、
    #                 本 override はファイルへの BOM 付与のみを追加する設計(upstream 追従)。
    def generate_csv
      super
      prepend_utf8_bom(export_tmp_file_path)
    end

    private

    def prepend_utf8_bom(path)
      return unless ::File.exist?(path)

      bom = "\xEF\xBB\xBF".b
      return if ::File.binread(path, bom.bytesize) == bom # 既に BOM 付きなら何もしない

      tmp_path = "#{path}.bom"
      ::File.open(tmp_path, 'wb') do |out|
        out.write(bom)
        ::File.open(path, 'rb') { |input| ::IO.copy_stream(input, out) }
      end
      ::File.rename(tmp_path, path)
    end
  end
end

Spree::Export.prepend(Spree::ExportDecorator)
