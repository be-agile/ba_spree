module BaSpree
  module Generators
    class InstallGenerator < Rails::Generators::Base
      class_option :auto_run_migrations, type: :boolean, default: false

      def add_javascripts
        js_directory = BaSpree::Engine.root.join('app', 'assets', 'javascripts')
        manifest_file = 'app/assets/config/manifest.js'
        Dir.glob("#{js_directory}/**/*.js").each do |file|
          relative_path = file.sub("#{js_directory}/", '')
          append_file manifest_file, "//= link #{relative_path}\n"
        end
      end

      def add_stylesheets
        css_directory = BaSpree::Engine.root.join('app', 'assets', 'stylesheets')
        manifest_file = 'app/assets/config/manifest.js'
        Dir.glob("#{css_directory}/**/*.scss").each do |file|
          relative_path = file.sub("#{css_directory}/", '').sub('.scss', '.css')
          append_file manifest_file, "//= link #{relative_path}\n"
        end
      end

      # ba_spree が束ねる engine の migration をまとめてコピーする。
      # 利用者が各 engine のジェネレータを 20 個順に叩かなくて済むようにするのが狙い。
      # @see https://github.com/be-agile/giga-repeat/issues/1317
      def add_migrations
        railties = migratable_railtie_names

        if railties.empty?
          say_status :skip, 'migration を持つ ba_spree の engine が見つかりませんでした', :yellow
          return
        end

        # FROM を省略すると spree 本体・spree_api・active_storage 等、
        # アプリにロードされている全 railtie からコピーしてしまうため必ず列挙する
        run "bundle exec rake railties:install:migrations FROM=#{railties.join(',')}"
      end

      def run_migrations
        if options[:auto_run_migrations] || [ '', 'y', 'Y' ].include?(ask('Would you like to run the migrations now? [Y/n]'))
          run 'bundle exec rake db:migrate'
        else
          say_status :skip, 'db:migrate をスキップしました。あとで実行してください', :yellow
        end
      end

      private

      # ba_spree の gemspec が依存に挙げている gem のうち、db/migrate を持つ
      # engine の railtie 名を返す。
      # gem 名と railtie 名は一致しないことがある
      # (例: ba_spree_loyalty_points gem の engine_name は spree_loyalty_points)
      # ため、gem のインストールパスと railtie の root を突き合わせて対応付ける。
      def migratable_railtie_names
        paths = dependency_gem_paths
        return [] if paths.empty?

        Rails.application.railties.filter_map do |railtie|
          next unless railtie.respond_to?(:root) && railtie.respond_to?(:railtie_name)
          next unless paths.include?(realpath(railtie.root))
          next unless railtie.paths['db/migrate']&.existent&.any?

          railtie.railtie_name
        end.uniq.sort
      end

      def dependency_gem_paths
        Gem::Specification.find_by_name('ba_spree').dependencies.select(&:runtime?).filter_map do |dependency|
          realpath(Gem::Specification.find_by_name(dependency.name).full_gem_path)
        rescue Gem::MissingSpecError
          nil
        end
      rescue Gem::MissingSpecError
        []
      end

      def realpath(path)
        File.realpath(path.to_s)
      rescue Errno::ENOENT
        nil
      end
    end
  end
end
