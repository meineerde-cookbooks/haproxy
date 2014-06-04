module HAProxy
  module TemplateHelpers
    def data(data_path)
      data_path.split('/').inject(node){ |hash, part| hash[part] }.to_hash
    end
  end
end
