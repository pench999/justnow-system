(function () {
  var state = {
    resource: 'hosts',
    detail: '',
    detailOid: '',
    query: '',
    limit: 50,
    offset: 0,
    total: 0,
    loading: false
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
    },
    ipaddresses: {
      label: 'IPアドレス',
      endpoint: '/ybz/api/v1/ipaddresses',
      render: renderIpAddress
    }
  };

  var results = document.getElementById('results');
  var status = document.getElementById('status');
  var searchForm = document.getElementById('search-form');
  var searchInput = document.getElementById('search-input');
  var loadMoreWrap = document.getElementById('load-more-wrap');
  var loadMoreButton = document.getElementById('load-more-button');
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

  function backAction(label, href) {
    return '<a class="back-link" href="' + escapeHtml(href) + '">' + escapeHtml(label) + '</a>';
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
        action('詳細', '#host/' + host.oid),
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
        action('詳細', '#service/' + service.oid),
        action('ホスト', '#hosts?service_oid=' + service.oid)
      ]
    });
  }

  function renderHostDetail(host) {
    var ips = [].concat(host.localips || [], host.globalips || [], host.virtualips || []);
    var rack = host.rackunit ? host.rackunit.label : '-';
    var rackUrl = host.rackunit && host.rackunit.rack ? '/ybz/rack/' + host.rackunit.rack.oid + '?highlight_host=' + host.oid : null;
    return '<div class="detail-nav">' + backAction('← ホスト一覧', '#hosts') + '</div>' +
      card({
        title: host.display_name || host.id || 'ホスト',
        badge: host.status || '',
        classes: ['detail-card', 'status-' + text(host.status, '').toLowerCase()],
        fields: [
          field('ID', text(host.id)),
          field('状態', text(host.status)),
          field('種別', text(host.type)),
          field('サービス', refLabel(host.service)),
          field('コンテンツ', refLabel(host.content)),
          linkField('ラック', rack, rackUrl),
          field('HWID', text(host.hwid)),
          field('HW情報', refLabel(host.hwinfo)),
          field('OS', text(host.os)),
          field('CPU', text(host.cpu)),
          field('メモリ', text(host.memory)),
          field('ディスク', text(host.disk)),
          field('DNS', join(host.dnsnames)),
          field('IP', join(ips)),
          field('子ホスト', join((host.children || []).map(function (child) { return child.label; }))),
          field('メモ', text(host.notes))
        ],
        actions: [
          action('PC版で開く', '/ybz/host/' + host.oid),
          host.service ? action('同サービスのホスト', '#hosts?service_oid=' + host.service.oid) : '',
          rackUrl ? action('ラック図', rackUrl) : ''
        ].filter(Boolean)
      });
  }

  function renderServiceDetail(service) {
    return '<div class="detail-nav">' + backAction('← サービス一覧', '#services') + '</div>' +
      card({
        title: service.name || 'サービス',
        badge: service.hypervisors ? 'HV' : '',
        classes: ['detail-card'],
        fields: [
          field('ID', text(service.id)),
          field('コンテンツ', refLabel(service.content)),
          field('ML', text(service.mladdress)),
          field('連絡先', refLabel(service.contact)),
          field('URL', join(service.urls)),
          field('HV候補', service.hypervisors ? 'あり' : '-'),
          field('メモ', text(service.notes))
        ],
        actions: [
          action('PC版で開く', '/ybz/service/' + service.oid),
          action('ホスト一覧', '#hosts?service_oid=' + service.oid)
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
        action('IP一覧', '#ipaddresses?segment_oid=' + segment.oid),
        action('PC版で開く', '/ybz/ipsegment/' + segment.oid)
      ]
    });
  }

  function renderIpAddress(ip) {
    var hosts = (ip.hosts || []).map(function (host) { return host.label; });
    return card({
      title: ip.address || 'IPアドレス',
      badge: ip.holder ? '予約' : (hosts.length > 0 ? '使用中' : ''),
      classes: [ip.holder ? 'status-standby' : (hosts.length > 0 ? 'status-in_service' : '')],
      fields: [
        field('種別', text(ip.version)),
        field('ホスト', join(hosts)),
        field('メモ', text(ip.notes))
      ],
      actions: [
        action('詳細', '#ipaddress/' + encodeURIComponent(ip.address)),
        hosts.length > 0 && ip.hosts[0] ? action('ホスト', '#host/' + ip.hosts[0].oid) : ''
      ].filter(Boolean)
    });
  }

  function renderIpAddressDetail(ip) {
    var hosts = (ip.hosts || []).map(function (host) { return host.label; });
    var hostActions = (ip.hosts || []).slice(0, 5).map(function (host) {
      return action(host.label, '#host/' + host.oid);
    });
    return '<div class="detail-nav">' + backAction('← IP一覧', '#ipaddresses') + '</div>' +
      card({
        title: ip.address || 'IPアドレス',
        badge: ip.holder ? '予約' : (hosts.length > 0 ? '使用中' : ''),
        classes: ['detail-card', ip.holder ? 'status-standby' : (hosts.length > 0 ? 'status-in_service' : '')],
        fields: [
          field('ID', text(ip.id)),
          field('種別', text(ip.version)),
          field('予約', ip.holder ? 'true' : '-'),
          field('ホスト', join(hosts)),
          field('メモ', text(ip.notes))
        ],
        actions: hostActions
      });
  }

  function setStatus(message) {
    status.textContent = message;
  }

  function resetPaging() {
    state.offset = 0;
    state.total = 0;
  }

  function setLoadMoreVisible(visible) {
    if (!loadMoreWrap) return;
    loadMoreWrap.classList.toggle('hidden', !visible);
  }

  function setLoadMoreLoading(loading) {
    state.loading = loading;
    if (!loadMoreButton) return;
    loadMoreButton.disabled = loading;
    loadMoreButton.textContent = loading ? '読み込み中...' : 'もっと見る';
  }

  function setActiveTab() {
    tabs.forEach(function (tab) {
      var resource = state.detail === 'host' ? 'hosts' : (state.detail === 'service' ? 'services' : (state.detail === 'ipaddress' ? 'ipaddresses' : state.resource));
      tab.classList.toggle('active', tab.getAttribute('data-resource') === resource);
    });
  }

  function parseHash() {
    var raw = location.hash.replace(/^#/, '');
    var parts = raw.split('?');
    var path = parts[0] || '';
    var detailMatch = path.match(/^(host|service)\/(\d+)$/) || path.match(/^(ipaddress)\/(.+)$/);
    state.detail = '';
    state.detailOid = '';
    if (detailMatch) {
      state.detail = detailMatch[1];
      state.detailOid = detailMatch[2];
      state.resource = state.detail === 'host' ? 'hosts' : 'services';
    } else if (path && resources[path]) {
      state.resource = path;
    }
    var params = new URLSearchParams(parts[1] || '');
    state.query = params.get('q') || '';
    state.serviceOid = params.get('service_oid') || '';
    state.segmentOid = params.get('segment_oid') || '';
    searchInput.value = state.query;
  }

  function updateHash() {
    var params = new URLSearchParams();
    if (state.query) params.set('q', state.query);
    if (state.serviceOid) params.set('service_oid', state.serviceOid);
    if (state.segmentOid) params.set('segment_oid', state.segmentOid);
    var query = params.toString();
    location.hash = state.resource + (query ? '?' + query : '');
  }

  function buildUrl() {
    var resource = resources[state.resource];
    var params = new URLSearchParams();
    params.set('limit', state.limit);
    params.set('offset', state.offset);
    if (state.query) params.set('q', state.query);
    if (state.resource === 'hosts' && state.serviceOid) params.set('service_oid', state.serviceOid);
    if (state.resource === 'ipaddresses' && state.segmentOid) params.set('segment_oid', state.segmentOid);
    return resource.endpoint + '?' + params.toString();
  }

  function buildDetailUrl() {
    if (state.detail === 'host') return '/ybz/api/v1/hosts/' + encodeURIComponent(state.detailOid);
    if (state.detail === 'service') return '/ybz/api/v1/services/' + encodeURIComponent(state.detailOid);
    if (state.detail === 'ipaddress') return '/ybz/api/v1/ipaddresses/' + encodeURIComponent(state.detailOid);
    return '';
  }

  function showUnauthorized() {
    setLoadMoreVisible(false);
    results.innerHTML = '<div class="empty"><strong>ログインが必要です</strong><span>ログイン後にモバイル画面へ戻ってください。</span><div class="actions"><a href="/ybz/authenticate/login">ログイン</a><a href="/ybz">PC版を開く</a></div></div>';
    setStatus('未ログイン');
  }

  function load(append) {
    append = !!append;
    if (state.detail) {
      resetPaging();
      setLoadMoreVisible(false);
      loadDetail();
      return;
    }
    var resource = resources[state.resource];
    setActiveTab();
    if (!append) {
      resetPaging();
      results.innerHTML = '';
    }
    setLoadMoreVisible(false);
    setLoadMoreLoading(true);
    setStatus(resource.label + 'を読み込み中...');

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
        var currentOffset = Number(meta.offset || 0);
        var count = Number(meta.count || data.length);
        var total = Number(meta.total || 0);
        var shown = currentOffset + count;
        if (data.length < 1 && !append) {
          var template = document.getElementById('empty-template');
          results.appendChild(template.content.cloneNode(true));
        } else {
          var html = data.map(resource.render).join('');
          if (append) {
            results.insertAdjacentHTML('beforeend', html);
          } else {
            results.innerHTML = html;
          }
        }
        state.offset = shown;
        state.total = total;
        setLoadMoreVisible(shown < total);
        setStatus(resource.label + ' ' + shown + '件 / 全' + text(total, shown) + '件');
      })
      .catch(function (error) {
        if (!append) {
          results.innerHTML = '<div class="empty"><strong>読み込みに失敗しました</strong><span>' + escapeHtml(error.message) + '</span></div>';
        }
        setLoadMoreVisible(append && state.offset < state.total);
        setStatus('エラー');
      })
      .finally(function () {
        setLoadMoreLoading(false);
      });
  }

  function loadDetail() {
    setLoadMoreVisible(false);
    setLoadMoreLoading(false);
    setActiveTab();
    var label = state.detail === 'host' ? 'ホスト詳細' : (state.detail === 'service' ? 'サービス詳細' : 'IP詳細');
    setStatus(label + 'を読み込み中...');
    results.innerHTML = '';

    fetch(buildDetailUrl(), { credentials: 'same-origin' })
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
        var data = payload.data;
        results.innerHTML = state.detail === 'host' ? renderHostDetail(data) : (state.detail === 'service' ? renderServiceDetail(data) : renderIpAddressDetail(data));
        setStatus(label);
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
      state.segmentOid = '';
      updateHash();
    });
  });

  searchForm.addEventListener('submit', function (event) {
    event.preventDefault();
    state.query = searchInput.value.trim();
    state.serviceOid = '';
    state.segmentOid = '';
    updateHash();
  });

  if (loadMoreButton) {
    loadMoreButton.addEventListener('click', function () {
      if (state.loading) return;
      load(true);
    });
  }

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
