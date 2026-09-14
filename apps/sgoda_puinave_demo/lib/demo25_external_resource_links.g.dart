// GENERATED FILE - DO NOT EDIT MANUALLY.
// SGODA Universal External Resource Link Engine 0..N

class Demo25ExternalResourceLink {
  const Demo25ExternalResourceLink({
    required this.id,
    required this.type,
    required this.label,
    required this.url,
    required this.platform,
    required this.status,
    required this.enabled,
    required this.visible,
    required this.publishable,
    required this.order,
  });

  final String id;
  final String type;
  final String label;
  final String url;
  final String platform;
  final String status;
  final bool enabled;
  final bool visible;
  final bool publishable;
  final int order;
}

const Map<String, List<Demo25ExternalResourceLink>>
demo25ExternalResourceLinks = {
  'puinave-bible': [
    Demo25ExternalResourceLink(
      id: 'puinave-bible-web',
      type: 'WEB',
      label: 'Biblia Puinave Web',
      url: 'https://www.scriptureearth.org/00eng.php?iso=pui',
      platform: 'ANY',
      status: 'VERIFIED',
      enabled: true,
      visible: true,
      publishable: true,
      order: 10,
    ),
    Demo25ExternalResourceLink(
      id: 'puinave-bible-puinave-sm',
      type: 'ANDROID_APP',
      label: 'Puinave SM',
      url: 'https://apk.fcbh.org/Puinave_SM',
      platform: 'ANY',
      status: 'VERIFIED',
      enabled: true,
      visible: true,
      publishable: true,
      order: 20,
    ),
  ],
  'puinave-photographic-archive': [],
  'puinave-documentary-interviews': [],
};

List<Demo25ExternalResourceLink> demo25PublicLinksForResource(
  String resourceId,
) {
  final links =
      demo25ExternalResourceLinks[resourceId] ??
      const <Demo25ExternalResourceLink>[];
  return links.where((link) => link.publishable).toList()
    ..sort((a, b) => a.order.compareTo(b.order));
}
