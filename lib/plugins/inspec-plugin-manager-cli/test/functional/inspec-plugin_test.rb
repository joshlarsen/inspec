#=========================================================================================#
#                      `inspec plugin SUBCOMMAND` facility
#=========================================================================================#
require_relative '../../../shared/core_plugin_test_helper.rb'

#-----------------------------------------------------------------------------------------#
#                                   utilities
#-----------------------------------------------------------------------------------------#
module PluginManagerHelpers
  let(:project_repo_path) { File.expand_path(File.join(__FILE__, '..', '..', '..')) }
  let(:project_fixtures_path) { File.join(project_repo_path, 'test', 'fixtures') }
  let(:project_config_dirs_path) { File.join(project_fixtures_path, 'config_dirs') }
  let(:empty_config_dir_path) { File.join(project_config_dirs_path, 'empty') }

  def copy_in_project_config_dir(fixture_name)
    src = Dir.glob(File.join(project_config_dirs_path, fixture_name, '*'))
    dest = File.join(project_config_dirs_path, 'empty')
    src.each { |path| FileUtils.cp_r(path, dest) }
  end

  def copy_in_core_config_dir(fixture_name)
    src = Dir.glob(File.join(core_config_dir_path, fixture_name, '*'))
    dest = File.join(project_config_dirs_path, 'empty')
    src.each { |path| FileUtils.cp_r(path, dest) }
  end

  def clear_empty_config_dir
    Dir.glob(File.join(project_config_dirs_path, 'empty', '*')).each do |path|
      next if path.end_with? '.gitkeep'
      FileUtils.rm_rf(path)
    end
  end

  def teardown
    clear_empty_config_dir
  end
end

#-----------------------------------------------------------------------------------------#
#                                   inspec help
#-----------------------------------------------------------------------------------------#
class PluginManagerCliHelp < MiniTest::Test
  include CorePluginFunctionalHelper

  # Main inspec help subcommand listing
  def test_inspec_help_includes_plugin
    result = run_inspec_process('help')
    assert_includes result.stdout, 'inspec plugin'
  end

  # inspec plugin help subcommand listing
  def test_inspec_plugin_help_includes_plugin
    result = run_inspec_process('plugin help')
    assert_includes result.stdout, 'inspec plugin list'
    assert_includes result.stdout, 'inspec plugin search'
    assert_includes result.stdout, 'inspec plugin install'
    assert_includes result.stdout, 'inspec plugin update'
    assert_includes result.stdout, 'inspec plugin uninstall'
  end
end

#-----------------------------------------------------------------------------------------#
#                                 inspec plugin list
#-----------------------------------------------------------------------------------------#
class PluginManagerCliList < MiniTest::Test
  include CorePluginFunctionalHelper
  include PluginManagerHelpers

  def test_list_when_no_user_plugins_installed
    result = run_inspec_process('plugin list', env: { INSPEC_CONFIG_DIR: empty_config_dir_path })
    assert_equal 0, result.exit_status, 'exist status must be 0'
    assert_includes result.stdout, '0 plugin(s) total', 'Empty list should include zero count'
  end

  def test_list_all_when_no_user_plugins_installed
    result = run_inspec_process('plugin list --all', env: { INSPEC_CONFIG_DIR: empty_config_dir_path })
    assert_equal 0, result.exit_status, 'exist status must be 0'
    assert_includes result.stdout, '6 plugin(s) total', '--all list should find six'
    assert_includes result.stdout, 'inspec-plugin-manager-cli', '--all list should find inspec-plugin-manager-cli'
    assert_includes result.stdout, 'habitat', '--all list should find habitat'

    result = run_inspec_process('plugin list -a', env: { INSPEC_CONFIG_DIR: empty_config_dir_path })
    assert_equal 0, result.exit_status, 'exist status must be 0'
    assert_includes result.stdout, '6 plugin(s) total', '-a list should find six'
  end

  def test_list_when_gem_and_path_plugins_installed
    fixture_path = File.join(core_config_dir_path, 'test-fixture-1-float')
    result = run_inspec_process('plugin list', env: { INSPEC_CONFIG_DIR: fixture_path })
    assert_equal 0, result.exit_status, 'exist status must be 0'
    assert_includes result.stdout, '2 plugin(s) total', 'gem+path should show two plugins'

    # Plugin Name                   Version   Via     ApiVer
    # -------------------------------------------------------
    #  inspec-meaning-of-life        src       path    2
    #  inspec-test-fixture           0.1.0     gem     2
    # -------------------------------------------------------
    #  2 plugin(s) total
    gem_line = result.stdout.split("\n").grep(/gem/).first
    assert_match(/\s*inspec-\S+\s+\d+\.\d+\.\d+\s+gem\s+2/, gem_line)
    path_line = result.stdout.split("\n").grep(/path/).first
    assert_match(/\s*inspec-\S+\s+src\s+path\s+2/, path_line)
  end
end

#-----------------------------------------------------------------------------------------#
#                               inspec plugin search
#-----------------------------------------------------------------------------------------#
class PluginManagerCliSearch < MiniTest::Test
  include CorePluginFunctionalHelper
  include PluginManagerHelpers

  def test_search_for_a_real_gem_with_full_name_no_options
    result = run_inspec_process('plugin search inspec-test-fixture')
    assert_equal 0, result.exit_status, 'Search should exit 0 on a hit'
    assert_includes result.stdout, 'inspec-test-fixture', 'Search result should contain the gem name'
    assert_includes result.stdout, '1 plugin(s) found', 'Search result should find 1 plugin'
    line = result.stdout.split("\n").grep(/inspec-test-fixture/).first
    assert_match(/\s*inspec-test-fixture\s+\((\d+\.\d+\.\d+){1}\)/,line,'Plugin line should include name and exactly one version')
  end

  def test_search_for_a_real_gem_with_stub_name_no_options
    result = run_inspec_process('plugin search inspec-test-')
    assert_equal 0, result.exit_status, 'Search should exit 0 on a hit'
    assert_includes result.stdout, 'inspec-test-fixture', 'Search result should contain the gem name'
    assert_includes result.stdout, '1 plugin(s) found', 'Search result should find 1 plugin'

    line = result.stdout.split("\n").grep(/inspec-test-fixture/).first
    assert_match(/\s*inspec-test-fixture\s+\((\d+\.\d+\.\d+){1}\)/,line,'Plugin line should include name and exactly one version')
  end

  def test_search_for_a_real_gem_with_full_name_and_exact_option
    result = run_inspec_process('plugin search --exact inspec-test-fixture')
    assert_equal 0, result.exit_status, 'Search should exit 0 on a hit'
    assert_includes result.stdout, 'inspec-test-fixture', 'Search result should contain the gem name'
    assert_includes result.stdout, '1 plugin(s) found', 'Search result should find 1 plugin'

    result = run_inspec_process('plugin search -e inspec-test-fixture')
    assert_equal 0, result.exit_status, 'Search should exit 0 on a hit'
  end

  def test_search_for_a_real_gem_with_stub_name_and_exact_option
    result = run_inspec_process('plugin search --exact inspec-test-')
    assert_equal 2, result.exit_status, 'Search should exit 2 on a miss'
    assert_includes result.stdout, '0 plugin(s) found', 'Search result should find 0 plugins'

    result = run_inspec_process('plugin search -e inspec-test-')
    assert_equal 2, result.exit_status, 'Search should exit 2 on a miss'
  end

  def test_search_for_a_real_gem_with_full_name_and_all_option
    result = run_inspec_process('plugin search --all inspec-test-fixture')
    assert_equal 0, result.exit_status, 'Search should exit 0 on a hit'
    assert_includes result.stdout, 'inspec-test-fixture', 'Search result should contain the gem name'
    assert_includes result.stdout, '1 plugin(s) found', 'Search result should find 1 plugin'

    line = result.stdout.split("\n").grep(/inspec-test-fixture/).first
    assert_match(/\s*inspec-test-fixture\s+\((\d+\.\d+\.\d+(,\s)?){2,}\)/,line,'Plugin line should include name and at least two versions')

    result = run_inspec_process('plugin search -a inspec-test-fixture')
    assert_equal 0, result.exit_status, 'Search should exit 0 on a hit'
  end

  def test_search_for_a_gem_with_missing_prefix
    result = run_inspec_process('plugin search test-fixture')
    assert_equal 1, result.exit_status, 'Search should exit 1 on user error'
    assert_includes result.stdout, "All inspec plugins must begin with either 'inspec-' or 'train-'"
  end

  def test_search_for_a_gem_that_does_not_exist
    result = run_inspec_process('plugin search inspec-test-fixture-nonesuch')
    assert_equal 2, result.exit_status, 'Search should exit 2 on a miss'
    assert_includes result.stdout, '0 plugin(s) found', 'Search result should find 0 plugins'
  end

end

#-----------------------------------------------------------------------------------------#
#                               inspec plugin install
#-----------------------------------------------------------------------------------------#
class PluginManagerCliInstall < MiniTest::Test
  include CorePluginFunctionalHelper # gives us instance methods, like `let` aliases inside test methods
  extend CorePluginFunctionalHelper  # gives us class methods, like `let` aliases out here outside test methods

  include PluginManagerHelpers

  # Test multiple hueristics of the path-mode install.
  # These are all positive tests; they should resolve the entry point to the same path in each case.
  {
    'is_perfect' => File.join(core_fixture_plugins_path, 'inspec-test-fixture', 'lib', 'inspec-test-fixture.rb'),
    'refers_to_the_entry_point_with_no_extension' => File.join(core_fixture_plugins_path, 'inspec-test-fixture', 'lib', 'inspec-test-fixture'),
    'refers_to_the_src_root_of_a_plugin' => File.join(core_fixture_plugins_path, 'inspec-test-fixture'),
    'refers_to_a_relative_path' => File.join('test', 'unit', 'mock', 'plugins', 'inspec-test-fixture', 'lib', 'inspec-test-fixture.rb'),
  }.each do |test_name, fixture_plugin_path|
    define_method(('test_install_from_path_when_path_' + test_name).to_sym) do
      working_dir = empty_config_dir_path
      install_result = run_inspec_process("plugin install #{fixture_plugin_path}", env: { INSPEC_CONFIG_DIR: working_dir })

      assert_empty install_result.stderr
      assert_equal 0, install_result.exit_status, 'Exit status should be 0'

      # Check UX messaging
      success_message = install_result.stdout.split("\n").grep(/installed/).last
      refute_nil success_message, 'Should find a success message at the end'
      assert_includes success_message, 'inspec-test-fixture'
      assert_includes success_message, 'plugin installed via source path reference'

      # Check round-trip UX via list
      list_result = run_inspec_process('plugin list', env: { INSPEC_CONFIG_DIR: working_dir })
      itf_line = list_result.stdout.split("\n").grep(/inspec-test-fixture/).first
      refute_nil itf_line, 'inspec-test-fixture should now appear in the output of inspec list'
      assert_match(/\s*inspec-test-fixture\s+src\s+path\s+/, itf_line, 'list output should show that it is a path installation')

      # Check plugin statefile. Extra important in this case, since all should resolve to the same entry point.
      plugin_data = JSON.parse(File.read(File.join(working_dir, 'plugins.json')))
      entry = plugin_data['plugins'].detect { |e| e['name'] == 'inspec-test-fixture' }
      expected = File.join(core_fixture_plugins_path, 'inspec-test-fixture', 'lib', 'inspec-test-fixture.rb')
      assert_equal expected, entry['installation_path'], 'Regardless of input, the entry point should be correct.'
    end
  end

  def test_fail_install_from_nonexistant_path
    bad_path = File.join(project_fixtures_path, 'none', 'such', 'inspec-test-fixture-nonesuch.rb')
    working_dir = empty_config_dir_path
    install_result = run_inspec_process("plugin install #{bad_path}", env: { INSPEC_CONFIG_DIR: working_dir })

    assert_empty install_result.stderr
    assert_equal 1, install_result.exit_status, 'Exit status should be 1'

    error_message = install_result.stdout.split("\n").last
    assert_includes error_message, "No such source code path"
    assert_includes error_message, 'inspec-test-fixture-nonesuch.rb'
    assert_includes error_message, 'installation failed'
  end

  def test_fail_install_from_path_with_wrong_name
    bad_path = File.join(project_fixtures_path, 'plugins', 'wrong-name', 'lib', 'wrong-name.rb')
    working_dir = empty_config_dir_path
    install_result = run_inspec_process("plugin install #{bad_path}", env: { INSPEC_CONFIG_DIR: working_dir })

    assert_empty install_result.stderr
    assert_equal 1, install_result.exit_status, 'Exit status should be 1'

    error_message = install_result.stdout.split("\n").last
    assert_includes error_message, "Invalid plugin name"
    assert_includes error_message, 'wrong-name'
    assert_includes error_message, "All inspec plugins must begin with either 'inspec-' or 'train-'"
    assert_includes error_message, 'installation failed'
  end

  def test_fail_install_from_path_when_it_is_not_a_plugin
    bad_path = File.join(project_fixtures_path, 'plugins', 'inspec-egg-white-omelette', 'lib', 'inspec-egg-white-omelette.rb')
    working_dir = empty_config_dir_path
    install_result = run_inspec_process("plugin install #{bad_path}", env: { INSPEC_CONFIG_DIR: working_dir })

    assert_empty install_result.stderr
    assert_equal 1, install_result.exit_status, 'Exit status should be 1'

    error_message = install_result.stdout.split("\n").last
    assert_includes error_message, "Does not appear to be a plugin"
    assert_includes error_message, 'inspec-egg-white-omelette.rb'
    assert_includes error_message, "After probe-loading the supposed plugin, it did not register."
    assert_includes error_message, "Ensure something inherits from 'Inspec.plugin(2)'"
    assert_includes error_message, 'installation failed'
  end

  def test_fail_install_from_path_when_it_is_already_installed
    plugin_path = File.join(core_fixture_plugins_path, 'inspec-test-fixture', 'lib', 'inspec-test-fixture.rb')
    working_dir = empty_config_dir_path
    first_install_result = run_inspec_process("plugin install #{plugin_path}", env: { INSPEC_CONFIG_DIR: working_dir })

    assert_empty first_install_result.stderr
    assert_equal 0, first_install_result.exit_status, 'Exit status on first install should be 0'

    second_install_result = run_inspec_process("plugin install #{plugin_path}", env: { INSPEC_CONFIG_DIR: working_dir })
    assert_empty second_install_result.stderr
    assert_equal 2, second_install_result.exit_status, 'Exit status on first install should be 2'

    error_message = second_install_result.stdout.split("\n").last
    assert_includes error_message, "Plugin already installed"
    assert_includes error_message, 'inspec-test-fixture'
    assert_includes error_message, "Use 'inspec plugin list' to see previously installed plugin"
    assert_includes error_message, 'installation failed'
  end

  def test_fail_install_from_path_when_the_dir_structure_is_wrong
    bad_path = File.join(project_fixtures_path, 'plugins', 'inspec-wrong-structure')
    working_dir = empty_config_dir_path
    install_result = run_inspec_process("plugin install #{bad_path}", env: { INSPEC_CONFIG_DIR: working_dir })

    assert_empty install_result.stderr
    assert_equal 1, install_result.exit_status, 'Exit status should be 1'

    error_message = install_result.stdout.split("\n").last
    assert_includes error_message, "Unrecognizable plugin structure"
    assert_includes error_message, 'inspec-wrong-structure'
    assert_includes error_message, ' When installing from a path, please provide the path of the entry point file'
    assert_includes error_message, 'installation failed'
  end

  def test_install_from_gemfile
    fixture_gemfile_path = File.join(core_fixture_plugins_path, 'inspec-test-fixture', 'pkg', 'inspec-test-fixture-0.1.0.gem')
    working_dir = empty_config_dir_path
    install_result = run_inspec_process("plugin install #{fixture_gemfile_path}", env: { INSPEC_CONFIG_DIR: working_dir })

    assert_empty install_result.stderr
    assert_equal 0, install_result.exit_status, 'Exit status should be 0'

    success_message = install_result.stdout.split("\n").grep(/installed/).last
    refute_nil success_message, 'Should find a success message at the end'
    assert_includes success_message, 'inspec-test-fixture'
    assert_includes success_message, '0.1.0'
    assert_includes success_message, 'installed from local .gem file'

    list_result = run_inspec_process('plugin list', env: { INSPEC_CONFIG_DIR: working_dir })
    itf_line = list_result.stdout.split("\n").grep(/inspec-test-fixture/).first
    refute_nil itf_line, 'inspec-test-fixture should now appear in the output of inspec list'
    assert_match(/\s*inspec-test-fixture\s+0.1.0\s+gem\s+/, itf_line, 'list output should show that it is a gem installation with version')
  end

  def test_fail_install_from_nonexistant_gemfile
    bad_path = File.join(project_fixtures_path, 'none', 'such', 'inspec-test-fixture-nonesuch-0.3.0.gem')
    working_dir = empty_config_dir_path
    install_result = run_inspec_process("plugin install #{bad_path}", env: { INSPEC_CONFIG_DIR: working_dir })

    assert_empty install_result.stderr
    assert_equal 1, install_result.exit_status, 'Exit status should be 1'
    assert_match(/No such plugin gem file .+ - installation failed./, install_result.stdout)
  end

  def test_install_from_rubygems_latest
    working_dir = empty_config_dir_path
    install_result = run_inspec_process('plugin install inspec-test-fixture', env: { INSPEC_CONFIG_DIR: working_dir })

    assert_empty install_result.stderr
    assert_equal 0, install_result.exit_status, 'Exit status should be 0'

    success_message = install_result.stdout.split("\n").grep(/installed/).last
    refute_nil success_message, 'Should find a success message at the end'
    assert_includes success_message, 'inspec-test-fixture'
    assert_includes success_message, '0.2.0'
    assert_includes success_message, 'installed from rubygems.org'

    list_result = run_inspec_process('plugin list', env: { INSPEC_CONFIG_DIR: working_dir })
    itf_line = list_result.stdout.split("\n").grep(/inspec-test-fixture/).first
    refute_nil itf_line, 'inspec-test-fixture should now appear in the output of inspec list'
    assert_match(/\s*inspec-test-fixture\s+0.2.0\s+gem\s+/, itf_line, 'list output should show that it is a gem installation with version')
  end

  def test_fail_install_from_nonexistant_remote_rubygem
    working_dir = empty_config_dir_path
    install_result = run_inspec_process('plugin install inspec-test-fixture-nonesuch', env: { INSPEC_CONFIG_DIR: working_dir })

    assert_empty install_result.stderr
    assert_equal 1, install_result.exit_status, 'Exit status should be 1'
    assert_match(/No such plugin gem .+ could be found on rubygems.org - installation failed./, install_result.stdout)
  end

  def test_install_from_rubygems_with_pinned_version
    working_dir = empty_config_dir_path
    install_result = run_inspec_process('plugin install inspec-test-fixture -v 0.1.0', env: { INSPEC_CONFIG_DIR: working_dir })

    assert_empty install_result.stderr
    assert_equal 0, install_result.exit_status, 'Exit status should be 0'

    success_message = install_result.stdout.split("\n").grep(/installed/).last
    refute_nil success_message, 'Should find a success message at the end'
    assert_includes success_message, 'inspec-test-fixture'
    assert_includes success_message, '0.1.0'
    assert_includes success_message, 'installed from rubygems.org'

    list_result = run_inspec_process('plugin list', env: { INSPEC_CONFIG_DIR: working_dir })
    itf_line = list_result.stdout.split("\n").grep(/inspec-test-fixture/).first
    refute_nil itf_line, 'inspec-test-fixture should now appear in the output of inspec list'
    assert_match(/\s*inspec-test-fixture\s+0.1.0\s+gem\s+/, itf_line, 'list output should show that it is a gem installation with version')
  end

  def test_fail_install_from_nonexistant_rubygem_version
    working_dir = empty_config_dir_path
    install_result = run_inspec_process('plugin install inspec-test-fixture -v 99.99.99', env: { INSPEC_CONFIG_DIR: working_dir })

    assert_empty install_result.stderr
    assert_equal 1, install_result.exit_status, 'Exit status should be 1'

    fail_message = install_result.stdout.split("\n").grep(/failed/).last
    refute_nil fail_message, 'Should find a failure message at the end'
    assert_includes fail_message, 'inspec-test-fixture'
    assert_includes fail_message, '99.99.99'
    assert_includes fail_message, 'no such version'
    assert_includes fail_message, 'on rubygems.org'
  end

  def test_refuse_install_when_missing_prefix
    working_dir = empty_config_dir_path
    install_result = run_inspec_process('plugin install test-fixture', env: { INSPEC_CONFIG_DIR: working_dir })

    assert_empty install_result.stderr
    assert_equal 1, install_result.exit_status, 'Exit status should be 1'

    fail_message = install_result.stdout.split("\n").grep(/failed/).last
    refute_nil fail_message, 'Should find a failure message at the end'
    assert_includes fail_message, 'test-fixture'
    assert_includes fail_message, "All inspec plugins must begin with either 'inspec-' or 'train-'"
  end

  def test_refuse_install_when_already_installed_same_version
    working_dir = empty_config_dir_path
    copy_in_core_config_dir('test-fixture-2-float')
    install_result = run_inspec_process('plugin install inspec-test-fixture', env: { INSPEC_CONFIG_DIR: working_dir })

    assert_empty install_result.stderr
    assert_equal 2, install_result.exit_status, 'Exit status should be 2'

    refusal_message = install_result.stdout.split("\n").grep(/refusing/).last
    refute_nil refusal_message, 'Should find a failure message at the end'
    assert_includes refusal_message, 'inspec-test-fixture'
    assert_includes refusal_message, '0.2.0'
    assert_includes refusal_message, 'Plugin already installed at latest version'
  end

  def test_refuse_install_when_already_installed_can_update
    working_dir = empty_config_dir_path
    copy_in_core_config_dir('test-fixture-1-float')
    install_result = run_inspec_process('plugin install inspec-test-fixture', env: { INSPEC_CONFIG_DIR: working_dir })

    assert_empty install_result.stderr
    assert_equal 2, install_result.exit_status, 'Exit status should be 2'

    refusal_message = install_result.stdout.split("\n").grep(/refusing/).last
    refute_nil refusal_message, 'Should find a failure message at the end'
    assert_includes refusal_message, 'inspec-test-fixture'
    assert_includes refusal_message, '0.1.0'
    assert_includes refusal_message, '0.2.0'
    assert_includes refusal_message, 'Update required'
    assert_includes refusal_message, 'inspec plugin update'
  end
end


#-----------------------------------------------------------------------------------------#
#                               inspec plugin update
#-----------------------------------------------------------------------------------------#
class PluginManagerCliUpdate < MiniTest::Test
  include CorePluginFunctionalHelper
  include PluginManagerHelpers

  def test_when_a_plugin_can_be_updated
    working_dir = empty_config_dir_path
    copy_in_core_config_dir('test-fixture-1-float')
    update_result = run_inspec_process('plugin update inspec-test-fixture', env: { INSPEC_CONFIG_DIR: working_dir })

    assert_empty update_result.stderr
    assert_equal 0, update_result.exit_status, 'Exit status should be 0'

    success_message = update_result.stdout.split("\n").grep(/updated/).last
    refute_nil success_message, 'Should find a success message at the end'
    assert_includes success_message, 'inspec-test-fixture'
    assert_includes success_message, '0.1.0'
    assert_includes success_message, '0.2.0'
    assert_includes success_message, 'updated from rubygems.org'

    list_result = run_inspec_process('plugin list', env: { INSPEC_CONFIG_DIR: working_dir })
    itf_line = list_result.stdout.split("\n").grep(/inspec-test-fixture/).first
    refute_nil itf_line, 'inspec-test-fixture should appear in the output of inspec list'
    assert_match(/\s*inspec-test-fixture\s+0.2.0\s+gem\s+/, itf_line, 'list output should show that it is a gem installation with version 0.2.0')
  end

  def test_refuse_update_when_already_current
    working_dir = empty_config_dir_path
    copy_in_core_config_dir('test-fixture-2-float')
    update_result = run_inspec_process('plugin update inspec-test-fixture', env: { INSPEC_CONFIG_DIR: working_dir })

    assert_empty update_result.stderr
    assert_equal 2, update_result.exit_status, 'Exit status should be 2'

    refusal_message = update_result.stdout.split("\n").grep(/refusing/).last
    refute_nil refusal_message, 'Should find a failure message at the end'
    assert_includes refusal_message, 'inspec-test-fixture'
    assert_includes refusal_message, '0.2.0'
    assert_includes refusal_message, 'Already installed at latest version'
  end

  def test_fail_update_from_nonexistant_gem
    working_dir = empty_config_dir_path
    update_result = run_inspec_process('plugin update inspec-test-fixture-nonesuch', env: { INSPEC_CONFIG_DIR: working_dir })

    assert_empty update_result.stderr
    assert_equal 1, update_result.exit_status, 'Exit status should be 1'
    assert_match(/No such plugin installed: .+ - update failed/, update_result.stdout)
  end

  def test_fail_update_path
    working_dir = empty_config_dir_path
    copy_in_core_config_dir('meaning_by_path')
    update_result = run_inspec_process('plugin update inspec-meaning-of-life', env: { INSPEC_CONFIG_DIR: working_dir })

    assert_empty update_result.stderr
    assert_equal 2, update_result.exit_status, 'Exit status should be 2'

    refusal_message = update_result.stdout.split("\n").grep(/refusing/).last
    refute_nil refusal_message, 'Should find a failure message at the end'
    assert_includes refusal_message, 'inspec-meaning-of-life'
    assert_includes refusal_message, 'inspec plugin uninstall'
    assert_includes refusal_message, 'Cannot update path-based install'
  end
end

#-----------------------------------------------------------------------------------------#
#                               inspec plugin uninstall
#-----------------------------------------------------------------------------------------#
class PluginManagerCliUninstall < MiniTest::Test
  include CorePluginFunctionalHelper
  include PluginManagerHelpers

  def test_when_a_gem_plugin_can_be_uninstalled
    working_dir = empty_config_dir_path
    copy_in_core_config_dir('test-fixture-1-float')

    # Verify it is installed as a gem first before we attempt uninstall
    list_result = run_inspec_process('plugin list', env: { INSPEC_CONFIG_DIR: working_dir })
    itf_line = list_result.stdout.split("\n").grep(/inspec-test-fixture/).first
    refute_nil itf_line, 'inspec-test-fixture should appear in the output of inspec list prior to uninstall'
    assert_match(/\s*inspec-test-fixture\s+0\.1\.0\s+gem\s+/, itf_line, 'list output should show that it is a gem installation')

    # Attempt uninstall
    uninstall_result = run_inspec_process('plugin uninstall inspec-test-fixture', env: { INSPEC_CONFIG_DIR: working_dir })

    assert_empty uninstall_result.stderr
    assert_equal 0, uninstall_result.exit_status, 'Exit status should be 0'

    success_message = uninstall_result.stdout.split("\n").grep(/uninstalled/).last
    refute_nil success_message, 'Should find a success message at the end'
    assert_includes success_message, 'inspec-test-fixture'
    assert_includes success_message, '0.1.0'
    assert_includes success_message, 'has been uninstalled'

    list_result = run_inspec_process('plugin list', env: { INSPEC_CONFIG_DIR: working_dir })
    itf_line = list_result.stdout.split("\n").grep(/inspec-test-fixture/).first
    assert_nil itf_line, 'inspec-test-fixture should not appear in the output of inspec list'
  end

  def test_when_a_path_plugin_can_be_uninstalled
    working_dir = empty_config_dir_path
    # This fixture includes a path install for inspec-meaning-of-life
    copy_in_core_config_dir('test-fixture-1-float')

    # Verify it is installed as a path first before we attempt uninstall
    list_result = run_inspec_process('plugin list', env: { INSPEC_CONFIG_DIR: working_dir })
    itf_line = list_result.stdout.split("\n").grep(/inspec-meaning-of-life/).first
    refute_nil itf_line, 'inspec-meaning-of-life should appear in the output of inspec list prior to uninstall'
    assert_match(/\s*inspec-meaning-of-life\s+src\s+path\s+/, itf_line, 'list output should show that it is a path installation')

    uninstall_result = run_inspec_process('plugin uninstall inspec-meaning-of-life', env: { INSPEC_CONFIG_DIR: working_dir })

    assert_empty uninstall_result.stderr
    assert_equal 0, uninstall_result.exit_status, 'Exit status should be 0'

    success_message = uninstall_result.stdout.split("\n").grep(/uninstalled/).last
    refute_nil success_message, 'Should find a success message at the end'
    assert_includes success_message, 'inspec-meaning-of-life'
    assert_includes success_message, 'path-based plugin install'
    assert_includes success_message, 'has been uninstalled'

    list_result = run_inspec_process('plugin list', env: { INSPEC_CONFIG_DIR: working_dir })
    itf_line = list_result.stdout.split("\n").grep(/inspec-meaning-of-life/).first
    assert_nil itf_line, 'inspec-meaning-of-life should not appear in the output of inspec list'
  end

  def test_fail_uninstall_from_plugin_that_is_not_installed
    working_dir = empty_config_dir_path
    uninstall_result = run_inspec_process('plugin uninstall inspec-test-fixture-nonesuch', env: { INSPEC_CONFIG_DIR: working_dir })

    assert_empty uninstall_result.stderr
    assert_equal 1, uninstall_result.exit_status, 'Exit status should be 1'
    refute_includes 'Inspec::Plugin::V2::UnInstallError', uninstall_result.stdout # Stacktrace marker
    assert_match(/No such plugin installed: .+ - uninstall failed/, uninstall_result.stdout)
  end
end
