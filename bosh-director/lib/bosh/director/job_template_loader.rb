require 'bosh/director/job_template_renderer'

module Bosh::Director
  class JobTemplateLoader
    def process(job_template)
      template_dir = extract_template(job_template)
      manifest = Psych.load_file(File.join(template_dir, 'job.MF'))

      monit_template = erb(File.join(template_dir, 'monit'))
      monit_template.filename = File.join(job_template.name, 'monit')

      templates = {}

      if manifest['templates']
        manifest['templates'].each_key do |template_name|
          template = erb(File.join(template_dir, 'templates', template_name))
          template.filename = File.join(job_template.name, template_name)
          templates[template_name] = template
        end
      end

      JobTemplateRenderer.new(job_template.name, monit_template, templates)
    ensure
      FileUtils.rm_rf(template_dir) if template_dir
    end

    private

    def extract_template(job_template)
      temp_path = job_template.download_blob
      template_dir = Dir.mktmpdir('template_dir')

      output = `tar -C #{template_dir} -xzf #{temp_path} 2>&1`
      if $?.exitstatus != 0
        raise JobTemplateUnpackFailed,
              "Cannot unpack `#{job_template.name}' job template, " +
                "tar returned #{$?.exitstatus}, " +
                "tar output: #{output}"
      end

      template_dir
    ensure
      FileUtils.rm_f(temp_path) if temp_path
    end

    def erb(path)
      ERB.new(File.read(path))
    end
  end
end
