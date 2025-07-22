import 'package:photo_manager/photo_manager.dart';

class GalleryService {
  Future<List<AssetPathEntity>> fetchAlbums() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) return [];
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.video,
      filterOption: FilterOptionGroup(
        videoOption: const FilterOption(durationConstraint: DurationConstraint(
          min: Duration(seconds: 1),
        )),
      ),
    );
    return albums;
  }

  Future<List<AssetEntity>> fetchVideos(AssetPathEntity album) async {
    return album.getAssetListPaged(page: 0, size: 100);
  }
} 