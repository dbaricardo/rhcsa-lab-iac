# -*- mode: ruby -*-
# vi: set ft=ruby :
#
# Topologia lida de machines.yaml (única fonte de verdade). Provider único:
# vagrant-libvirt. O box "rhel10-rhcsa-base" é gerado localmente por
# scripts/build-box.sh (ver README/docs/tutorial-fim-a-fim.md) — não existe
# em nenhum registro público, já que embute a ativação da subscription do
# usuário final.

require 'yaml'

ROOT = File.dirname(File.expand_path(__FILE__))
SPEC = YAML.load_file(File.join(ROOT, 'machines.yaml'))

STUDENT_USER = SPEC.dig('student', 'username') || 'student'
BOX_NAME     = SPEC['box']
DOMAIN       = SPEC['domain']
NET_NAME     = SPEC.dig('network', 'libvirt_name')
MACHINES     = SPEC['machines']

# Ordem determinística: workstation por último, para que o provisioner
# Ansible (disparado uma única vez na última máquina, ansible.limit "all")
# só rode depois que servera/serverb já estão de pé — evita condição de
# corrida no role ssh_crosshost.
ORDERED_NAMES = MACHINES.keys.sort_by { |name| name == 'workstation' ? 1 : 0 }

Vagrant.configure('2') do |config|
  ORDERED_NAMES.each do |name|
    spec = MACHINES[name]
    is_last = (name == ORDERED_NAMES.last)

    config.vm.define name do |node|
      node.vm.box = BOX_NAME
      node.vm.hostname = "#{name}.#{DOMAIN}"

      node.vm.network 'private_network',
                       ip: spec['ip'],
                       libvirt__network_name: NET_NAME,
                       libvirt__dhcp_enabled: false

      node.vm.provider :libvirt do |lv|
        lv.memory = spec['memory_mb']
        lv.cpus   = spec['cpus']
        lv.default_prefix = 'rhcsa-lab'

        Array(spec['extra_disks']).each do |disk|
          lv.storage :file,
                      size: "#{disk['size_gb']}G",
                      type: 'qcow2'
          # O tamanho é a única forma confiável de identificar o disco depois
          # (a ordem /dev/sdb vs /dev/sdc já inverteu entre boots em produção
          # real) — por isso os roles Ansible resolvem discos por tamanho via
          # lab-common.sh (resolve_disco()), nunca por nome de dispositivo.
        end
      end

      # Disparado uma única vez, depois que todas as VMs existem, contra o
      # inventário completo (ansible.limit "all") — o playbook cuida da
      # ordem interna (common -> ssh_crosshost -> roles por host -> dashboard).
      if is_last
        node.vm.provision 'ansible' do |ansible|
          ansible.playbook = 'ansible/site.yml'
          ansible.limit = 'all'
          ansible.groups = {
            'servera' => ['servera'],
            'serverb' => ['serverb'],
            'workstation' => ['workstation'],
            'lab_hosts' => %w[servera serverb],
          }
          ansible.extra_vars = {
            lab_domain: DOMAIN,
            lab_student_user: STUDENT_USER,
            lab_network_cidr: SPEC.dig('network', 'cidr'),
            dashboard_host: SPEC.dig('dashboard', 'host'),
            dashboard_port: SPEC.dig('dashboard', 'port'),
            dashboard_allowed_source: SPEC.dig('dashboard', 'allowed_source'),
            workstation_ip: MACHINES.dig('workstation', 'ip'),
            servera_ip: MACHINES.dig('servera', 'ip'),
            serverb_ip: MACHINES.dig('serverb', 'ip'),
          }
        end
      end
    end
  end
end
