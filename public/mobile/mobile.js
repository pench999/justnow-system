(function () {
  var state = {
    resource: 'hosts',
    query: '',
    limit: 50
  };

  var resources = {
    hosts: {
      label: 'ホスト',
      endpoint: '/ybz/api/v1/hosts',
      render: renderHost
    },
    services: {
      label: 'サービス',
      endpoint: '/ybz/api/v1/services',
      render: renderService
    },
    racks: {
      label: 'ラック',
      endpoint: '/ybz/api/v1/racks',
      render: renderRack
    },
    ipsegments: {
      label: 'IPセグメント',
      endpoint: '/ybz/api/v1/ipsegments',
      render: renderIpSegment
    }
  };

  var results = document.getElementById('results');
  var status = document.getElementById('status');
  var searchForm = document.getElementById('search-form');
  var searchInput = document.getElementById('search-input');
  var tabs = Array.prototype.slice.call(document.querySelectorAll('.tab'));

  function text(value, fallback) {
    if (value === null || value === undefined || value === '') return fallback || '-';
    return String(value);
  }

  function join(values) {
    var filtered = (values || []).filter(function (value) {
      return value !== null && value !== undefined && value !== '';
    });
    return filtered.length > 0 ? filtered.join(', ') : '-';
  }

  function refLabel(ref) {
    return ref && ref.label ? ref.label : '-';
  }

  function escapeHtml(value) {
    return text(value, '').replace(/[&<>"']/g, function (char) {
      return {
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#39;'
      }[char];
    });
  }

  function field(label, value) {
    return '<div class="field"><span class="label">' + escapeHtml(label) + '</span><span class="value">' + escapeHtml(value) + '</span></div>';
  }

  function linkField(label, value, href) {
    if (!href) return field(label, value);
    return '<div class="field"><span class="label">' + escapeHtml(label) + '</span><span class="value"><a href="' + escapeHtml(href) + '">' + escapeHtml(value) + '</a></span></div>';
  }

  function card(options) {
    var css = ['card'].concat(options.classes || []).join(' ');
    return '<article class="' + css + '">' +
      '<div class="card-title"><span>' + escapeHtml(options.title) + '</span>' +
      (options.badge ? '<b class="badge">' + escapeHtml(options.badge) + '</b>' : '') +
      '</div>' +
      '<div class="fields">' + options.fields.join('') + '</div>' +
      (options.actions && options.actions.length > 0 ? '<div class="actions">' + options.actions.join('') + '</div>' : '') +
      '</article>';
  }

  function action(label, href) {
    return '<a href="' + escapeHtml(href) + '">' + escapeHtml(label) + '</a>';
  }

  function renderHost(host) {
    var ips = [].concat(host.localips || [], host.globalips || [], host.virtualips || []);
    var rack = host.rackunit ? host.rackunit.label : '-';
    var rackUrl = host.rackunit && host.rackunit.rack ? '/ybz/rack/' + host.rackunit.rack.oid + '?highlight_host=' + host.oid : null;
    return card({
      title: host.display_name || host.id || 'ホスト',
      badge: host.status || '',
      classes: ['status-' + text(host.status, '').toLowerCase()],
      fields: [
        field('IP', join(ips)),
        field('サービス', refLabel(host.service)),
        linkField('ラック', rack, rackUrl),
        field('種別', join([host.type, refLabel(host.hwinfo)])),
        field('OS', text(host.os))
      ],
      actions: [
        action('詳細', '/ybz/host/' + host.oid),
        host.service ? action('同サービス', '#hosts?service_oid=' + host.service.oid) : '',
        rackUrl ? action('ラック図', rackUrl) : ''
      ].filter(Boolean)
    });
  }

  function renderService(service) {
    return card({
      title: service.name || 'サービス',
      badge: service.hypervisors ? 'HV' : '',
      fields: [
        field('コンテンツ', refLabel(service.content)),
        field('ML', text(service.mladdress)),
        field('連絡先', refLabel(service.contact)),
        field('URL', join(service.urls))
      ],
      actions: [
        action('詳細', '/ybz/service/' + service.oid),
        action('ホスト', '#hosts?service_oid=' + service.oid)
      ]
    });
  }

  function renderRack(rack) {
    return card({
      title: rack.label || 'ラック',
      badge: rack.ongoing ? '利用可' : '使用不可',
      classes: [rack.ongoing ? 'ongoing' : 'stopped'],
      fields: [
        field('DC', text(rack.datacenter)),
        field('種別', text(rack.type)),
        field('メモ', rack.notes ? 'あり' : '-')
      ],
      actions: [
        action('ラック図', '/ybz/rack/' + rack.oid)
      ]
    });
  }

  function renderIpSegment(segment) {
    return card({
      title: segment.cidr || (segment.address + '/' + segment.netmask),
      badge: segment.area || '',
      classes: [segment.ongoing ? 'ongoing' : 'stopped'],
      fields: [
        field('IP種別', text(segment.version)),
        field('範囲', text(segment.area)),
        field('状態', segment.ongoing ? '利用中' : '停止'),
        field('メモ', segment.notes ? 'あり' : '-')
      ],
      actions: [
        action('IP一覧', '/ybz/ipsegment/' + segment.oid)
      ]
    });
  }

  function setStatus(message) {
    status.textContent = message;
  }

  function setActiveTab() {
    tabs.forEach(function (tab) {
      tab.classList.toggle('active', tab.getAttribute('data-resource') === state.resource);
    });
  }

  function parseHash() {
    var raw = location.hash.replace(/^#/, '');
    var parts = raw.split('?');
    if (parts[0] && resources[parts[0]]) state.resource = parts[0];
    var params = new URLSearchParams(parts[1] || '');
    state.query = params.get('q') || '';
    state.serviceOid = params.get('service_oid') || '';
    searchInput.value = state.query;
  }

  function updateHash() {
    var params = new URLSearchParams();
    if (state.query) params.set('q', state.query);
    if (state.serviceOid) params.set('service_oid', state.serviceOid);
    var query = params.toString();
    location.hash = state.resource + (query ? '?' + query : '');
  }

  function buildUrl() {
    var resource = resources[state.resource];
    var params = new URLSearchParams();
    params.set('limit', state.limit);
    if (state.query) params.set('q', state.query);
    if (state.resource === 'hosts' && state.serviceOid) params.set('service_oid', state.serviceOid);
    return resource.endpoint + '?' + params.toString();
  }

  function showUnauthorized() {
    results.innerHTML = '<div class="empty"><strong>ログインが必要です</strong><span>ログイン後にモバイル画面へ戻ってください。</span><div class="actions"><a href="/ybz/authenticate/login">ログイン</a><a href="/ybz">PC版を開く</a></div></div>';
    setStatus('未ログイン');
  }

  function load() {
    var resource = resources[state.resource];
    setActiveTab();
    setStatus(resource.label + 'を読み込み中...');
    results.innerHTML = '';

    fetch(buildUrl(), { credentials: 'same-origin' })
      .then(function (response) {
        if (response.status === 401) {
          showUnauthorized();
          return null;
        }
        if (!response.ok) throw new Error('HTTP ' + response.status);
        return response.json();
      })
      .then(function (payload) {
        if (!payload) return;
        var data = payload.data || [];
        var meta = payload.meta || {};
        if (data.length < 1) {
          var template = document.getElementById('empty-template');
          results.appendChild(template.content.cloneNode(true));
        } else {
          results.innerHTML = data.map(resource.render).join('');
        }
        setStatus(resource.label + ' ' + data.length + '件 / 全' + text(meta.total, data.length) + '件');
      })
      .catch(function (error) {
        results.innerHTML = '<div class="empty"><strong>読み込みに失敗しました</strong><span>' + escapeHtml(error.message) + '</span></div>';
        setStatus('エラー');
      });
  }

  tabs.forEach(function (tab) {
    tab.addEventListener('click', function () {
      state.resource = tab.getAttribute('data-resource');
      state.serviceOid = '';
      updateHash();
    });
  });

  searchForm.addEventListener('submit', function (event) {
    event.preventDefault();
    state.query = searchInput.value.trim();
    state.serviceOid = '';
    updateHash();
  });

  window.addEventListener('hashchange', function () {
    parseHash();
    load();
  });

  if (!location.hash) {
    location.hash = 'hosts';
  } else {
    parseHash();
    load();
  }
}());
