# frozen_string_literal: true

require_relative './environment'

# Fetches GH Project Issues
class Job
  class << self
    def persist_issues(project_info, issues)
      project = Project.find_or_initialize_by(number: project_info[:number]).tap do |project|
        project.title = project_info[:title]
        project.number = project_info[:number]
        project.public = project_info[:public]
        project.closed = project_info[:closed]
        project.url = project_info[:url]
        project.save
      end

      issues.each do |issue_data|
        sprints =
          issue_data[:fieldValues][:nodes]
          .select { |node| node.key?(:iterationId) }
          .map do |sprint_data|
            Sprint.find_or_initialize_by(iteration_id: sprint_data[:iterationId]).tap do |sprint|
              sprint.assign_attributes(
                title: sprint_data[:title],
                start_date: sprint_data[:startDate],
                duration: sprint_data[:duration],
                project_id: project.id
              )
              sprint.save
            end
          end

        issue = Issue.find_or_initialize_by(number: issue_data[:content][:number])
        issue.title = issue_data[:content][:title]
        sprints.each do |sprint|
          next if issue.sprints.include?(sprint)

          issue.sprints << sprint
        end

        fields = issue_data[:fieldValues][:nodes].map do |node|
          next unless node[:field] && node[:field][:name]

          key = node[:field][:name]
          value = node[:text] || node[:name] || node[:number] || node[:title]
          [key, value]
        end.compact.to_h
        issue.points = fields['Points']
        issue.status = fields['Status']
        issue.state = issue_data[:content][:state]
        issue.url = issue_data[:content][:url]
        issue.data = issue_data
        issue.closed_at = issue_data[:content][:closedAt]
        issue.save
      end
    end

    def run(projects = Project.all)
      if projects.empty?
        ENV['SEED_GH_PROJECT_URLS'].split(',').each do |url|
          number = url.match(%r{github.com/orgs/[^/]+/projects/(\d+)}).captures.first
          Project.create(number:, url:)
        end
      end

      projects.each do |project|
        organization, number = project.url.match(%r{github.com/orgs/([^/]+)/projects/(\d+)}).captures
        project = Github::Project.new(token: ENV.fetch('GH_TOKEN'), organization:, number:)
        persist_issues project.info, project.issues
      end

      $logger.info 'Finished Job.' # rubocop:disable Style/GlobalVars
    end
  end
end

# rubocop:disable Style/GlobalVars
if __FILE__ == $PROGRAM_NAME
  $logger.info('Starting Job.')

  # Run the job
  loop do
    Job.run
    $logger.info "Sleeping until #{Time.now + 10.minutes}..."
    sleep 60 * 10
  end

  $logger.error('Job exited.')
  exit 1
end
# rubocop:enable Style/GlobalVars
