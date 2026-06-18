'use strict';

const GITHUB_BASE = 'https://github.com/joevue123/devops-portfolio/tree/main';

const PROJECTS = [
  {
    id: '01',
    title: 'Linux System Health Monitor',
    tier: 'tier-1',
    icon: '🖥️',
    summary: 'Dependency-free Bash script monitoring CPU, memory, disk, and load — with configurable thresholds and Slack/email alerting.',
    problem: 'Ops teams need early warning on resource exhaustion before services degrade.',
    skills: ['bash', 'cron', 'linux', 'alerting'],
    files: [
      'monitor.sh          — main monitoring script',
      'config.env.example  — threshold and alerting config',
    ],
    decisions: [
      'Pure Bash — works on any Linux host, zero dependencies',
      'Configurable thresholds via env file — no script edits needed',
      'Exit code 1 on alert — integrates with cron and monitoring systems',
    ],
    path: 'tier-1-foundational/01-linux-system-monitor',
  },
  {
    id: '02',
    title: 'Git Workflow Automation',
    tier: 'tier-1',
    icon: '🪝',
    summary: 'Pre-commit hooks and commit-msg validation enforcing Conventional Commits, secret scanning, branch naming policies, and 7 code quality checks.',
    problem: 'Teams waste review cycles on formatting issues and accidentally commit secrets.',
    skills: ['git', 'bash', 'pre-commit', 'security'],
    files: [
      '.pre-commit-config.yaml  — 7 hooks including detect-secrets',
      'hooks/commit-msg         — Conventional Commits enforcer',
      'hooks/pre-push           — branch naming policy',
      'install-hooks.sh         — one-command install into any repo',
    ],
    decisions: [
      'pre-commit framework over raw hooks — versioned and shareable',
      'detect-secrets runs first — cheapest blocker, stops secrets before CI',
      'Conventional Commits — enables automatic changelog + semver bumping',
    ],
    path: 'tier-1-foundational/02-git-workflow-automation',
  },
  {
    id: '03',
    title: 'Docker Multi-Stage Build',
    tier: 'tier-1',
    icon: '🐳',
    summary: 'Four-stage Dockerfile producing a 35MB distroless production image from a 1.2GB naive baseline — 97% smaller, no shell, non-root.',
    problem: 'Naive Docker images bloat to 1GB+ and expose unnecessary attack surface.',
    skills: ['docker', 'typescript', 'security', 'optimization'],
    files: [
      'Dockerfile     — 4 stages: deps, builder, test, production',
      '.dockerignore  — excludes node_modules, test files, git history',
      'src/index.ts   — minimal Node.js HTTP server',
    ],
    decisions: [
      'Distroless base — no shell means attackers cannot exec into the container',
      'Separate test stage — test tooling never enters production image',
      'Non-root user (uid 65532) — prevents privilege escalation',
    ],
    path: 'tier-1-foundational/03-docker-multistage-build',
  },
  {
    id: '04',
    title: 'Docker Compose Full Stack',
    tier: 'tier-1',
    icon: '📦',
    summary: 'Production-style Compose stack: Nginx reverse proxy + Node.js API + PostgreSQL + Redis, with isolated networks, health checks, and resource limits.',
    problem: 'Inconsistent local environments cause "works on my machine" failures.',
    skills: ['docker', 'docker-compose', 'nginx', 'postgresql', 'redis'],
    files: [
      'docker-compose.yml          — full stack with healthchecks',
      'nginx/conf.d/app.conf       — proxy, caching, rate limits',
      '.env.example                — environment variable template',
    ],
    decisions: [
      'Two isolated networks — frontend/backend separation; DB unreachable from Nginx',
      'Health check conditions on depends_on — API waits for DB to be truly ready',
      'Named volumes not bind mounts — portable across dev machines and CI',
    ],
    path: 'tier-1-foundational/04-docker-compose-stack',
  },
  {
    id: '05',
    title: 'GitHub Actions CI Pipeline',
    tier: 'tier-1',
    icon: '⚙️',
    summary: 'Full CI pipeline: lint → matrix tests across Node 18/20/22 → Trivy + Gitleaks security scan → OIDC push to ECR → staging deploy with Slack notify.',
    problem: 'A CI pipeline that just runs tests misses security, multi-version regressions, and safe cloud auth.',
    skills: ['github-actions', 'ci-cd', 'docker', 'aws', 'security'],
    files: [
      '.github/workflows/ci.yml  — complete 6-job pipeline',
    ],
    decisions: [
      'OIDC for AWS auth — no long-lived credentials stored in GitHub Secrets',
      'Matrix builds across Node 18/20/22 — catch version regressions early',
      'Lint runs first — cheapest check gates all others',
      'Multi-arch build (amd64 + arm64) — ARM cost savings on AWS Graviton',
    ],
    path: 'tier-1-foundational/05-github-actions-ci',
  },
  {
    id: '06',
    title: 'Terraform AWS Infrastructure',
    tier: 'tier-1',
    icon: '🏗️',
    summary: 'Three-tier AWS architecture in Terraform: VPC with NAT HA, Auto Scaling Group + ALB, RDS Multi-AZ, ElastiCache. Remote S3 state with DynamoDB locking.',
    problem: 'Console-clicked infrastructure is impossible to reproduce, audit, or version control.',
    skills: ['terraform', 'aws', 'vpc', 'iac'],
    files: [
      'main.tf              — root module wiring all components',
      'variables.tf         — all inputs with validation',
      'modules/vpc/main.tf  — VPC, subnets, IGW, NAT, route tables',
      'envs/staging.tfvars  — staging environment values',
      'envs/production.tfvars',
    ],
    decisions: [
      'Remote state in S3 + DynamoDB locking — safe for team use',
      'Workspaces for environments — same code, different tfvars',
      'NAT Gateway per AZ — prevents single-AZ network failure',
      'RDS Multi-AZ — automatic failover, no manual intervention',
    ],
    path: 'tier-1-foundational/06-terraform-aws-infra',
  },
  {
    id: '07',
    title: 'Nginx Reverse Proxy',
    tier: 'tier-1',
    icon: '🔀',
    summary: 'Production Nginx config with weighted upstream load balancing, TLS termination, rate limiting, proxy caching, and structured JSON access logs.',
    problem: 'Directly exposing app servers is insecure and unscalable.',
    skills: ['nginx', 'ssl', 'load-balancing', 'caching'],
    files: [
      'nginx/nginx.conf              — worker, events, rate limit zones',
      'nginx/conf.d/upstream.conf    — weighted round-robin pool',
      'docker-compose.yml            — full local stack for testing',
      'scripts/gen-self-signed-cert.sh',
    ],
    decisions: [
      'Separate rate limit zones per route — API and login limited more strictly',
      'keepalive 32 in upstream — connection pooling reduces TCP overhead',
      'JSON access logs — structured for direct ingestion into ELK/Loki',
      'proxy_cache_use_stale — serves stale content during upstream errors',
    ],
    path: 'tier-1-foundational/07-nginx-reverse-proxy',
  },
  {
    id: '08',
    title: 'ELK Log Aggregation',
    tier: 'tier-1',
    icon: '📊',
    summary: 'Complete ELK stack: Filebeat ships logs → Logstash parses with grok/geoip/useragent → Elasticsearch with ILM tiering → Kibana dashboards.',
    problem: 'Logs scattered across dozens of servers are impossible to correlate or search.',
    skills: ['elasticsearch', 'logstash', 'kibana', 'docker'],
    files: [
      'docker-compose.yml                — 5-service stack with log generator',
      'logstash/pipeline/main.conf        — grok, geoip, useragent, date parsing',
      'filebeat/filebeat.yml              — ships nginx, app, and Docker logs',
      'elasticsearch/ilm-policy.json      — hot/warm/delete tiering',
    ],
    decisions: [
      'ILM policy — automatic data tiering prevents disk exhaustion',
      'Filebeat over Logstash agent on source hosts — lightweight on servers',
      'Drop /health check logs — removes noise before it enters the pipeline',
    ],
    path: 'tier-1-foundational/08-elk-log-aggregation',
  },
  {
    id: '09',
    title: 'Ansible Server Hardening',
    tier: 'tier-1',
    icon: '🔒',
    summary: 'Idempotent Ansible playbooks applying CIS Level 1 benchmarks: SSH hardening, UFW firewall, kernel sysctl params, and auditd — across a multi-role fleet.',
    problem: 'Manually configured servers drift from their intended state and fail audits.',
    skills: ['ansible', 'linux', 'security', 'cis'],
    files: [
      'site.yml                              — master playbook',
      'roles/security/tasks/ssh.yml          — disable root, password auth',
      'roles/security/tasks/firewall.yml     — UFW rules per host group',
      'roles/security/tasks/sysctl.yml       — 10 CIS kernel params',
      'inventories/production/hosts.yml',
    ],
    decisions: [
      'Ansible Vault for secrets — never plaintext passwords in inventory',
      '--check --diff before every production run — review before applying',
      'Handlers for restarts — services only restart if config actually changed',
      'Tags on every task — allows surgical targeting without full playbook',
    ],
    path: 'tier-1-foundational/09-ansible-server-hardening',
  },
  {
    id: '10',
    title: 'Kubernetes App Deployment',
    tier: 'tier-1',
    icon: '☸️',
    summary: 'Full K8s deployment with Deployment (zero-downtime rolling), HPA, Ingress, PodDisruptionBudget, NetworkPolicy, and Kustomize overlays for staging/production.',
    problem: 'A bare Deployment and Service is not production-ready Kubernetes.',
    skills: ['kubernetes', 'kustomize', 'helm', 'hpa'],
    files: [
      'k8s/base/deployment.yaml     — readiness/liveness/startup probes, anti-affinity',
      'k8s/base/hpa.yaml            — CPU + memory autoscaling with scale-down cool-down',
      'k8s/base/pdb.yaml            — minAvailable: 2 during node drains',
      'k8s/base/networkpolicy.yaml  — ingress-only traffic to pods',
      'k8s/overlays/staging/        — 1 replica override for staging',
    ],
    decisions: [
      'maxUnavailable: 0 — zero-downtime deployments always maintain full capacity',
      'Startup probe separate from liveness — prevents premature kill during slow boot',
      'PodDisruptionBudget — ensures 2 pods stay up during node drain/upgrades',
      'Kustomize overlays — same base manifests for all environments',
    ],
    path: 'tier-1-foundational/10-kubernetes-app-deployment',
  },
];

// ── Rendering ────────────────────────────────────────────────────────────────

function renderProjects(filter) {
  const grid = document.getElementById('projects-grid');
  grid.innerHTML = '';

  const filtered = filter === 'all'
    ? PROJECTS
    : PROJECTS.filter(p =>
        p.tier === filter ||
        p.skills.some(s => s.toLowerCase().includes(filter))
      );

  filtered.forEach(project => {
    const card = document.createElement('article');
    card.className = 'project-card';
    card.setAttribute('data-tier', project.tier);
    card.setAttribute('data-id', project.id);

    card.innerHTML = `
      <div class="project-card-header">
        <span class="project-number">#${project.id}</span>
        <span class="tier-badge ${project.tier}">Tier ${project.tier.split('-')[1]}</span>
      </div>
      <div style="display:flex;align-items:flex-start;gap:10px">
        <span class="project-icon">${project.icon}</span>
        <h3>${project.title}</h3>
      </div>
      <p>${project.summary}</p>
      <div class="project-skills">
        ${project.skills.map(s => `<span class="skill-tag">${s}</span>`).join('')}
      </div>
      <div class="project-card-footer">
        <span class="view-link">
          View details
          <svg width="12" height="12" viewBox="0 0 16 16" fill="currentColor">
            <path d="M1 8a.5.5 0 01.5-.5h11.793l-3.147-3.146a.5.5 0 01.708-.708l4 4a.5.5 0 010 .708l-4 4a.5.5 0 01-.708-.708L13.293 8.5H1.5A.5.5 0 011 8z"/>
          </svg>
        </span>
        <a href="${GITHUB_BASE}/${project.path}" target="_blank" rel="noopener"
           class="btn btn-outline" style="font-size:11px;padding:4px 10px"
           onclick="event.stopPropagation()">
          Source
        </a>
      </div>
    `;

    card.addEventListener('click', () => openModal(project));
    grid.appendChild(card);
  });

  // Show/hide coming-soon based on filter
  const comingSoon = document.getElementById('coming-soon');
  comingSoon.style.display = (filter === 'all') ? '' : 'none';
}

// ── Modal ─────────────────────────────────────────────────────────────────────

function openModal(project) {
  const overlay = document.getElementById('modal-overlay');
  const content = document.getElementById('modal-content');

  content.innerHTML = `
    <div class="modal-header">
      <span class="modal-icon">${project.icon}</span>
      <div>
        <div style="display:flex;align-items:center;gap:8px;margin-bottom:4px">
          <span class="tier-badge ${project.tier}">Tier ${project.tier.split('-')[1]}</span>
          <span style="font-family:var(--mono);font-size:11px;color:var(--text-dim)">#${project.id}</span>
        </div>
        <h2 class="modal-title">${project.title}</h2>
        <p class="modal-subtitle">${project.summary}</p>
      </div>
    </div>

    <div class="modal-section">
      <h4>Problem Statement</h4>
      <p>${project.problem}</p>
    </div>

    <div class="modal-section">
      <h4>Key Files</h4>
      <div class="modal-files">${project.files.join('\n')}</div>
    </div>

    <div class="modal-section">
      <h4>Engineering Decisions</h4>
      <ul style="padding-left:20px;font-size:14px;color:var(--text-muted);line-height:2">
        ${project.decisions.map(d => `<li>${d}</li>`).join('')}
      </ul>
    </div>

    <div class="modal-section">
      <h4>Skills</h4>
      <div class="modal-skills">
        ${project.skills.map(s => `<span class="skill-tag">${s}</span>`).join('')}
      </div>
    </div>

    <div class="modal-actions">
      <a href="${GITHUB_BASE}/${project.path}" target="_blank" rel="noopener" class="btn btn-primary">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0024 12c0-6.63-5.37-12-12-12z"/></svg>
        View on GitHub
      </a>
      <a href="${GITHUB_BASE}/${project.path}/README.md" target="_blank" rel="noopener" class="btn btn-outline">
        Read README
      </a>
    </div>
  `;

  overlay.classList.add('open');
  overlay.setAttribute('aria-hidden', 'false');
  document.body.style.overflow = 'hidden';
}

function closeModal() {
  const overlay = document.getElementById('modal-overlay');
  overlay.classList.remove('open');
  overlay.setAttribute('aria-hidden', 'true');
  document.body.style.overflow = '';
}

// ── Filters ──────────────────────────────────────────────────────────────────

document.querySelectorAll('.filter-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');

    const tierHeading = document.getElementById('tier-1-heading');
    const filter = btn.dataset.filter;
    tierHeading.style.display = filter === 'all' ? '' : 'none';

    renderProjects(filter);
  });
});

document.getElementById('modal-close').addEventListener('click', closeModal);
document.getElementById('modal-overlay').addEventListener('click', e => {
  if (e.target === e.currentTarget) closeModal();
});
document.addEventListener('keydown', e => {
  if (e.key === 'Escape') closeModal();
});

// ── Init ─────────────────────────────────────────────────────────────────────
renderProjects('all');
