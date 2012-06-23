module CarrierWave
  module Video
    class FfmpegTheora
      attr_reader :input_path, :output_path
      def initialize(input_file_path, output_file_path)
        @input_path = input_file_path
        @output_path = output_file_path
      end

      def run(logger=nil)
        cmd = "#{CarrierWave::Video.ffmpeg2theora_binary} #{input_path} -o #{output_path}"
        logger.info("Running....#{cmd}") if logger
        outputs = []
        exit_code = nil

        Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
          stderr.each("r") do |line|
            outputs << line
          end
          exit_code = wait_thr.value
        end

        handle_exit_code(exit_code, outputs, logger)
      end

      private
      def handle_exit_code(exit_code, outputs, logger)
        return unless logger
        if exit_code == 0
          logger.info("Success!")
        else
          outputs.each do |output|
            logger.error(output)
          end
          logger.error("Failure!")
        end
        exit_code
      end
    end
  end
end
