// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'lib.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FfiCommand {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FfiCommand()';
}


}

/// @nodoc
class $FfiCommandCopyWith<$Res>  {
$FfiCommandCopyWith(FfiCommand _, $Res Function(FfiCommand) __);
}


/// Adds pattern-matching-related methods to [FfiCommand].
extension FfiCommandPatterns on FfiCommand {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( FfiCommand_Pause value)?  pause,TResult Function( FfiCommand_Resume value)?  resume,TResult Function( FfiCommand_Toggle value)?  toggle,TResult Function( FfiCommand_Stop value)?  stop,TResult Function( FfiCommand_SeekMs value)?  seekMs,TResult Function( FfiCommand_SetVolume value)?  setVolume,TResult Function( FfiCommand_PlaySong value)?  playSong,TResult Function( FfiCommand_QueueAdd value)?  queueAdd,TResult Function( FfiCommand_QueueRemove value)?  queueRemove,TResult Function( FfiCommand_QueueClear value)?  queueClear,TResult Function( FfiCommand_Next value)?  next,TResult Function( FfiCommand_Previous value)?  previous,TResult Function( FfiCommand_Search value)?  search,TResult Function( FfiCommand_SearchMore value)?  searchMore,TResult Function( FfiCommand_LibraryRefresh value)?  libraryRefresh,TResult Function( FfiCommand_FavoritesAdd value)?  favoritesAdd,TResult Function( FfiCommand_FavoritesRemove value)?  favoritesRemove,TResult Function( FfiCommand_FavoritePlaylistAdd value)?  favoritePlaylistAdd,TResult Function( FfiCommand_FavoritePlaylistRemove value)?  favoritePlaylistRemove,TResult Function( FfiCommand_HistoryRemove value)?  historyRemove,TResult Function( FfiCommand_HistoryClear value)?  historyClear,TResult Function( FfiCommand_CustomPlaylistCreate value)?  customPlaylistCreate,TResult Function( FfiCommand_CustomPlaylistRename value)?  customPlaylistRename,TResult Function( FfiCommand_CustomPlaylistDelete value)?  customPlaylistDelete,TResult Function( FfiCommand_CustomPlaylistAddSongs value)?  customPlaylistAddSongs,TResult Function( FfiCommand_CustomPlaylistRemoveSong value)?  customPlaylistRemoveSong,TResult Function( FfiCommand_CustomPlaylistDetail value)?  customPlaylistDetail,TResult Function( FfiCommand_ConfigGet value)?  configGet,TResult Function( FfiCommand_ConfigUpdate value)?  configUpdate,TResult Function( FfiCommand_DownloadEnqueue value)?  downloadEnqueue,TResult Function( FfiCommand_DownloadCancel value)?  downloadCancel,TResult Function( FfiCommand_DownloadClearFinished value)?  downloadClearFinished,TResult Function( FfiCommand_QrLoginStart value)?  qrLoginStart,TResult Function( FfiCommand_QrLoginCancel value)?  qrLoginCancel,TResult Function( FfiCommand_LocalScan value)?  localScan,TResult Function( FfiCommand_AccountPlaylists value)?  accountPlaylists,TResult Function( FfiCommand_AccountFavorites value)?  accountFavorites,TResult Function( FfiCommand_AccountPlaylistDetail value)?  accountPlaylistDetail,TResult Function( FfiCommand_SyncPreview value)?  syncPreview,TResult Function( FfiCommand_SyncRun value)?  syncRun,TResult Function( FfiCommand_SyncCancel value)?  syncCancel,TResult Function( FfiCommand_PushTargets value)?  pushTargets,TResult Function( FfiCommand_PushCreateTarget value)?  pushCreateTarget,TResult Function( FfiCommand_PushPlan value)?  pushPlan,TResult Function( FfiCommand_PushRun value)?  pushRun,TResult Function( FfiCommand_PushCancel value)?  pushCancel,TResult Function( FfiCommand_PlaylistCategories value)?  playlistCategories,TResult Function( FfiCommand_PlaylistList value)?  playlistList,TResult Function( FfiCommand_PlaylistDetail value)?  playlistDetail,TResult Function( FfiCommand_LeaderboardBoards value)?  leaderboardBoards,TResult Function( FfiCommand_LeaderboardSongs value)?  leaderboardSongs,TResult Function( FfiCommand_ArtistSongs value)?  artistSongs,TResult Function( FfiCommand_ArtistAlbums value)?  artistAlbums,TResult Function( FfiCommand_AlbumSongs value)?  albumSongs,TResult Function( FfiCommand_PlaySongs value)?  playSongs,required TResult orElse(),}){
final _that = this;
switch (_that) {
case FfiCommand_Pause() when pause != null:
return pause(_that);case FfiCommand_Resume() when resume != null:
return resume(_that);case FfiCommand_Toggle() when toggle != null:
return toggle(_that);case FfiCommand_Stop() when stop != null:
return stop(_that);case FfiCommand_SeekMs() when seekMs != null:
return seekMs(_that);case FfiCommand_SetVolume() when setVolume != null:
return setVolume(_that);case FfiCommand_PlaySong() when playSong != null:
return playSong(_that);case FfiCommand_QueueAdd() when queueAdd != null:
return queueAdd(_that);case FfiCommand_QueueRemove() when queueRemove != null:
return queueRemove(_that);case FfiCommand_QueueClear() when queueClear != null:
return queueClear(_that);case FfiCommand_Next() when next != null:
return next(_that);case FfiCommand_Previous() when previous != null:
return previous(_that);case FfiCommand_Search() when search != null:
return search(_that);case FfiCommand_SearchMore() when searchMore != null:
return searchMore(_that);case FfiCommand_LibraryRefresh() when libraryRefresh != null:
return libraryRefresh(_that);case FfiCommand_FavoritesAdd() when favoritesAdd != null:
return favoritesAdd(_that);case FfiCommand_FavoritesRemove() when favoritesRemove != null:
return favoritesRemove(_that);case FfiCommand_FavoritePlaylistAdd() when favoritePlaylistAdd != null:
return favoritePlaylistAdd(_that);case FfiCommand_FavoritePlaylistRemove() when favoritePlaylistRemove != null:
return favoritePlaylistRemove(_that);case FfiCommand_HistoryRemove() when historyRemove != null:
return historyRemove(_that);case FfiCommand_HistoryClear() when historyClear != null:
return historyClear(_that);case FfiCommand_CustomPlaylistCreate() when customPlaylistCreate != null:
return customPlaylistCreate(_that);case FfiCommand_CustomPlaylistRename() when customPlaylistRename != null:
return customPlaylistRename(_that);case FfiCommand_CustomPlaylistDelete() when customPlaylistDelete != null:
return customPlaylistDelete(_that);case FfiCommand_CustomPlaylistAddSongs() when customPlaylistAddSongs != null:
return customPlaylistAddSongs(_that);case FfiCommand_CustomPlaylistRemoveSong() when customPlaylistRemoveSong != null:
return customPlaylistRemoveSong(_that);case FfiCommand_CustomPlaylistDetail() when customPlaylistDetail != null:
return customPlaylistDetail(_that);case FfiCommand_ConfigGet() when configGet != null:
return configGet(_that);case FfiCommand_ConfigUpdate() when configUpdate != null:
return configUpdate(_that);case FfiCommand_DownloadEnqueue() when downloadEnqueue != null:
return downloadEnqueue(_that);case FfiCommand_DownloadCancel() when downloadCancel != null:
return downloadCancel(_that);case FfiCommand_DownloadClearFinished() when downloadClearFinished != null:
return downloadClearFinished(_that);case FfiCommand_QrLoginStart() when qrLoginStart != null:
return qrLoginStart(_that);case FfiCommand_QrLoginCancel() when qrLoginCancel != null:
return qrLoginCancel(_that);case FfiCommand_LocalScan() when localScan != null:
return localScan(_that);case FfiCommand_AccountPlaylists() when accountPlaylists != null:
return accountPlaylists(_that);case FfiCommand_AccountFavorites() when accountFavorites != null:
return accountFavorites(_that);case FfiCommand_AccountPlaylistDetail() when accountPlaylistDetail != null:
return accountPlaylistDetail(_that);case FfiCommand_SyncPreview() when syncPreview != null:
return syncPreview(_that);case FfiCommand_SyncRun() when syncRun != null:
return syncRun(_that);case FfiCommand_SyncCancel() when syncCancel != null:
return syncCancel(_that);case FfiCommand_PushTargets() when pushTargets != null:
return pushTargets(_that);case FfiCommand_PushCreateTarget() when pushCreateTarget != null:
return pushCreateTarget(_that);case FfiCommand_PushPlan() when pushPlan != null:
return pushPlan(_that);case FfiCommand_PushRun() when pushRun != null:
return pushRun(_that);case FfiCommand_PushCancel() when pushCancel != null:
return pushCancel(_that);case FfiCommand_PlaylistCategories() when playlistCategories != null:
return playlistCategories(_that);case FfiCommand_PlaylistList() when playlistList != null:
return playlistList(_that);case FfiCommand_PlaylistDetail() when playlistDetail != null:
return playlistDetail(_that);case FfiCommand_LeaderboardBoards() when leaderboardBoards != null:
return leaderboardBoards(_that);case FfiCommand_LeaderboardSongs() when leaderboardSongs != null:
return leaderboardSongs(_that);case FfiCommand_ArtistSongs() when artistSongs != null:
return artistSongs(_that);case FfiCommand_ArtistAlbums() when artistAlbums != null:
return artistAlbums(_that);case FfiCommand_AlbumSongs() when albumSongs != null:
return albumSongs(_that);case FfiCommand_PlaySongs() when playSongs != null:
return playSongs(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( FfiCommand_Pause value)  pause,required TResult Function( FfiCommand_Resume value)  resume,required TResult Function( FfiCommand_Toggle value)  toggle,required TResult Function( FfiCommand_Stop value)  stop,required TResult Function( FfiCommand_SeekMs value)  seekMs,required TResult Function( FfiCommand_SetVolume value)  setVolume,required TResult Function( FfiCommand_PlaySong value)  playSong,required TResult Function( FfiCommand_QueueAdd value)  queueAdd,required TResult Function( FfiCommand_QueueRemove value)  queueRemove,required TResult Function( FfiCommand_QueueClear value)  queueClear,required TResult Function( FfiCommand_Next value)  next,required TResult Function( FfiCommand_Previous value)  previous,required TResult Function( FfiCommand_Search value)  search,required TResult Function( FfiCommand_SearchMore value)  searchMore,required TResult Function( FfiCommand_LibraryRefresh value)  libraryRefresh,required TResult Function( FfiCommand_FavoritesAdd value)  favoritesAdd,required TResult Function( FfiCommand_FavoritesRemove value)  favoritesRemove,required TResult Function( FfiCommand_FavoritePlaylistAdd value)  favoritePlaylistAdd,required TResult Function( FfiCommand_FavoritePlaylistRemove value)  favoritePlaylistRemove,required TResult Function( FfiCommand_HistoryRemove value)  historyRemove,required TResult Function( FfiCommand_HistoryClear value)  historyClear,required TResult Function( FfiCommand_CustomPlaylistCreate value)  customPlaylistCreate,required TResult Function( FfiCommand_CustomPlaylistRename value)  customPlaylistRename,required TResult Function( FfiCommand_CustomPlaylistDelete value)  customPlaylistDelete,required TResult Function( FfiCommand_CustomPlaylistAddSongs value)  customPlaylistAddSongs,required TResult Function( FfiCommand_CustomPlaylistRemoveSong value)  customPlaylistRemoveSong,required TResult Function( FfiCommand_CustomPlaylistDetail value)  customPlaylistDetail,required TResult Function( FfiCommand_ConfigGet value)  configGet,required TResult Function( FfiCommand_ConfigUpdate value)  configUpdate,required TResult Function( FfiCommand_DownloadEnqueue value)  downloadEnqueue,required TResult Function( FfiCommand_DownloadCancel value)  downloadCancel,required TResult Function( FfiCommand_DownloadClearFinished value)  downloadClearFinished,required TResult Function( FfiCommand_QrLoginStart value)  qrLoginStart,required TResult Function( FfiCommand_QrLoginCancel value)  qrLoginCancel,required TResult Function( FfiCommand_LocalScan value)  localScan,required TResult Function( FfiCommand_AccountPlaylists value)  accountPlaylists,required TResult Function( FfiCommand_AccountFavorites value)  accountFavorites,required TResult Function( FfiCommand_AccountPlaylistDetail value)  accountPlaylistDetail,required TResult Function( FfiCommand_SyncPreview value)  syncPreview,required TResult Function( FfiCommand_SyncRun value)  syncRun,required TResult Function( FfiCommand_SyncCancel value)  syncCancel,required TResult Function( FfiCommand_PushTargets value)  pushTargets,required TResult Function( FfiCommand_PushCreateTarget value)  pushCreateTarget,required TResult Function( FfiCommand_PushPlan value)  pushPlan,required TResult Function( FfiCommand_PushRun value)  pushRun,required TResult Function( FfiCommand_PushCancel value)  pushCancel,required TResult Function( FfiCommand_PlaylistCategories value)  playlistCategories,required TResult Function( FfiCommand_PlaylistList value)  playlistList,required TResult Function( FfiCommand_PlaylistDetail value)  playlistDetail,required TResult Function( FfiCommand_LeaderboardBoards value)  leaderboardBoards,required TResult Function( FfiCommand_LeaderboardSongs value)  leaderboardSongs,required TResult Function( FfiCommand_ArtistSongs value)  artistSongs,required TResult Function( FfiCommand_ArtistAlbums value)  artistAlbums,required TResult Function( FfiCommand_AlbumSongs value)  albumSongs,required TResult Function( FfiCommand_PlaySongs value)  playSongs,}){
final _that = this;
switch (_that) {
case FfiCommand_Pause():
return pause(_that);case FfiCommand_Resume():
return resume(_that);case FfiCommand_Toggle():
return toggle(_that);case FfiCommand_Stop():
return stop(_that);case FfiCommand_SeekMs():
return seekMs(_that);case FfiCommand_SetVolume():
return setVolume(_that);case FfiCommand_PlaySong():
return playSong(_that);case FfiCommand_QueueAdd():
return queueAdd(_that);case FfiCommand_QueueRemove():
return queueRemove(_that);case FfiCommand_QueueClear():
return queueClear(_that);case FfiCommand_Next():
return next(_that);case FfiCommand_Previous():
return previous(_that);case FfiCommand_Search():
return search(_that);case FfiCommand_SearchMore():
return searchMore(_that);case FfiCommand_LibraryRefresh():
return libraryRefresh(_that);case FfiCommand_FavoritesAdd():
return favoritesAdd(_that);case FfiCommand_FavoritesRemove():
return favoritesRemove(_that);case FfiCommand_FavoritePlaylistAdd():
return favoritePlaylistAdd(_that);case FfiCommand_FavoritePlaylistRemove():
return favoritePlaylistRemove(_that);case FfiCommand_HistoryRemove():
return historyRemove(_that);case FfiCommand_HistoryClear():
return historyClear(_that);case FfiCommand_CustomPlaylistCreate():
return customPlaylistCreate(_that);case FfiCommand_CustomPlaylistRename():
return customPlaylistRename(_that);case FfiCommand_CustomPlaylistDelete():
return customPlaylistDelete(_that);case FfiCommand_CustomPlaylistAddSongs():
return customPlaylistAddSongs(_that);case FfiCommand_CustomPlaylistRemoveSong():
return customPlaylistRemoveSong(_that);case FfiCommand_CustomPlaylistDetail():
return customPlaylistDetail(_that);case FfiCommand_ConfigGet():
return configGet(_that);case FfiCommand_ConfigUpdate():
return configUpdate(_that);case FfiCommand_DownloadEnqueue():
return downloadEnqueue(_that);case FfiCommand_DownloadCancel():
return downloadCancel(_that);case FfiCommand_DownloadClearFinished():
return downloadClearFinished(_that);case FfiCommand_QrLoginStart():
return qrLoginStart(_that);case FfiCommand_QrLoginCancel():
return qrLoginCancel(_that);case FfiCommand_LocalScan():
return localScan(_that);case FfiCommand_AccountPlaylists():
return accountPlaylists(_that);case FfiCommand_AccountFavorites():
return accountFavorites(_that);case FfiCommand_AccountPlaylistDetail():
return accountPlaylistDetail(_that);case FfiCommand_SyncPreview():
return syncPreview(_that);case FfiCommand_SyncRun():
return syncRun(_that);case FfiCommand_SyncCancel():
return syncCancel(_that);case FfiCommand_PushTargets():
return pushTargets(_that);case FfiCommand_PushCreateTarget():
return pushCreateTarget(_that);case FfiCommand_PushPlan():
return pushPlan(_that);case FfiCommand_PushRun():
return pushRun(_that);case FfiCommand_PushCancel():
return pushCancel(_that);case FfiCommand_PlaylistCategories():
return playlistCategories(_that);case FfiCommand_PlaylistList():
return playlistList(_that);case FfiCommand_PlaylistDetail():
return playlistDetail(_that);case FfiCommand_LeaderboardBoards():
return leaderboardBoards(_that);case FfiCommand_LeaderboardSongs():
return leaderboardSongs(_that);case FfiCommand_ArtistSongs():
return artistSongs(_that);case FfiCommand_ArtistAlbums():
return artistAlbums(_that);case FfiCommand_AlbumSongs():
return albumSongs(_that);case FfiCommand_PlaySongs():
return playSongs(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( FfiCommand_Pause value)?  pause,TResult? Function( FfiCommand_Resume value)?  resume,TResult? Function( FfiCommand_Toggle value)?  toggle,TResult? Function( FfiCommand_Stop value)?  stop,TResult? Function( FfiCommand_SeekMs value)?  seekMs,TResult? Function( FfiCommand_SetVolume value)?  setVolume,TResult? Function( FfiCommand_PlaySong value)?  playSong,TResult? Function( FfiCommand_QueueAdd value)?  queueAdd,TResult? Function( FfiCommand_QueueRemove value)?  queueRemove,TResult? Function( FfiCommand_QueueClear value)?  queueClear,TResult? Function( FfiCommand_Next value)?  next,TResult? Function( FfiCommand_Previous value)?  previous,TResult? Function( FfiCommand_Search value)?  search,TResult? Function( FfiCommand_SearchMore value)?  searchMore,TResult? Function( FfiCommand_LibraryRefresh value)?  libraryRefresh,TResult? Function( FfiCommand_FavoritesAdd value)?  favoritesAdd,TResult? Function( FfiCommand_FavoritesRemove value)?  favoritesRemove,TResult? Function( FfiCommand_FavoritePlaylistAdd value)?  favoritePlaylistAdd,TResult? Function( FfiCommand_FavoritePlaylistRemove value)?  favoritePlaylistRemove,TResult? Function( FfiCommand_HistoryRemove value)?  historyRemove,TResult? Function( FfiCommand_HistoryClear value)?  historyClear,TResult? Function( FfiCommand_CustomPlaylistCreate value)?  customPlaylistCreate,TResult? Function( FfiCommand_CustomPlaylistRename value)?  customPlaylistRename,TResult? Function( FfiCommand_CustomPlaylistDelete value)?  customPlaylistDelete,TResult? Function( FfiCommand_CustomPlaylistAddSongs value)?  customPlaylistAddSongs,TResult? Function( FfiCommand_CustomPlaylistRemoveSong value)?  customPlaylistRemoveSong,TResult? Function( FfiCommand_CustomPlaylistDetail value)?  customPlaylistDetail,TResult? Function( FfiCommand_ConfigGet value)?  configGet,TResult? Function( FfiCommand_ConfigUpdate value)?  configUpdate,TResult? Function( FfiCommand_DownloadEnqueue value)?  downloadEnqueue,TResult? Function( FfiCommand_DownloadCancel value)?  downloadCancel,TResult? Function( FfiCommand_DownloadClearFinished value)?  downloadClearFinished,TResult? Function( FfiCommand_QrLoginStart value)?  qrLoginStart,TResult? Function( FfiCommand_QrLoginCancel value)?  qrLoginCancel,TResult? Function( FfiCommand_LocalScan value)?  localScan,TResult? Function( FfiCommand_AccountPlaylists value)?  accountPlaylists,TResult? Function( FfiCommand_AccountFavorites value)?  accountFavorites,TResult? Function( FfiCommand_AccountPlaylistDetail value)?  accountPlaylistDetail,TResult? Function( FfiCommand_SyncPreview value)?  syncPreview,TResult? Function( FfiCommand_SyncRun value)?  syncRun,TResult? Function( FfiCommand_SyncCancel value)?  syncCancel,TResult? Function( FfiCommand_PushTargets value)?  pushTargets,TResult? Function( FfiCommand_PushCreateTarget value)?  pushCreateTarget,TResult? Function( FfiCommand_PushPlan value)?  pushPlan,TResult? Function( FfiCommand_PushRun value)?  pushRun,TResult? Function( FfiCommand_PushCancel value)?  pushCancel,TResult? Function( FfiCommand_PlaylistCategories value)?  playlistCategories,TResult? Function( FfiCommand_PlaylistList value)?  playlistList,TResult? Function( FfiCommand_PlaylistDetail value)?  playlistDetail,TResult? Function( FfiCommand_LeaderboardBoards value)?  leaderboardBoards,TResult? Function( FfiCommand_LeaderboardSongs value)?  leaderboardSongs,TResult? Function( FfiCommand_ArtistSongs value)?  artistSongs,TResult? Function( FfiCommand_ArtistAlbums value)?  artistAlbums,TResult? Function( FfiCommand_AlbumSongs value)?  albumSongs,TResult? Function( FfiCommand_PlaySongs value)?  playSongs,}){
final _that = this;
switch (_that) {
case FfiCommand_Pause() when pause != null:
return pause(_that);case FfiCommand_Resume() when resume != null:
return resume(_that);case FfiCommand_Toggle() when toggle != null:
return toggle(_that);case FfiCommand_Stop() when stop != null:
return stop(_that);case FfiCommand_SeekMs() when seekMs != null:
return seekMs(_that);case FfiCommand_SetVolume() when setVolume != null:
return setVolume(_that);case FfiCommand_PlaySong() when playSong != null:
return playSong(_that);case FfiCommand_QueueAdd() when queueAdd != null:
return queueAdd(_that);case FfiCommand_QueueRemove() when queueRemove != null:
return queueRemove(_that);case FfiCommand_QueueClear() when queueClear != null:
return queueClear(_that);case FfiCommand_Next() when next != null:
return next(_that);case FfiCommand_Previous() when previous != null:
return previous(_that);case FfiCommand_Search() when search != null:
return search(_that);case FfiCommand_SearchMore() when searchMore != null:
return searchMore(_that);case FfiCommand_LibraryRefresh() when libraryRefresh != null:
return libraryRefresh(_that);case FfiCommand_FavoritesAdd() when favoritesAdd != null:
return favoritesAdd(_that);case FfiCommand_FavoritesRemove() when favoritesRemove != null:
return favoritesRemove(_that);case FfiCommand_FavoritePlaylistAdd() when favoritePlaylistAdd != null:
return favoritePlaylistAdd(_that);case FfiCommand_FavoritePlaylistRemove() when favoritePlaylistRemove != null:
return favoritePlaylistRemove(_that);case FfiCommand_HistoryRemove() when historyRemove != null:
return historyRemove(_that);case FfiCommand_HistoryClear() when historyClear != null:
return historyClear(_that);case FfiCommand_CustomPlaylistCreate() when customPlaylistCreate != null:
return customPlaylistCreate(_that);case FfiCommand_CustomPlaylistRename() when customPlaylistRename != null:
return customPlaylistRename(_that);case FfiCommand_CustomPlaylistDelete() when customPlaylistDelete != null:
return customPlaylistDelete(_that);case FfiCommand_CustomPlaylistAddSongs() when customPlaylistAddSongs != null:
return customPlaylistAddSongs(_that);case FfiCommand_CustomPlaylistRemoveSong() when customPlaylistRemoveSong != null:
return customPlaylistRemoveSong(_that);case FfiCommand_CustomPlaylistDetail() when customPlaylistDetail != null:
return customPlaylistDetail(_that);case FfiCommand_ConfigGet() when configGet != null:
return configGet(_that);case FfiCommand_ConfigUpdate() when configUpdate != null:
return configUpdate(_that);case FfiCommand_DownloadEnqueue() when downloadEnqueue != null:
return downloadEnqueue(_that);case FfiCommand_DownloadCancel() when downloadCancel != null:
return downloadCancel(_that);case FfiCommand_DownloadClearFinished() when downloadClearFinished != null:
return downloadClearFinished(_that);case FfiCommand_QrLoginStart() when qrLoginStart != null:
return qrLoginStart(_that);case FfiCommand_QrLoginCancel() when qrLoginCancel != null:
return qrLoginCancel(_that);case FfiCommand_LocalScan() when localScan != null:
return localScan(_that);case FfiCommand_AccountPlaylists() when accountPlaylists != null:
return accountPlaylists(_that);case FfiCommand_AccountFavorites() when accountFavorites != null:
return accountFavorites(_that);case FfiCommand_AccountPlaylistDetail() when accountPlaylistDetail != null:
return accountPlaylistDetail(_that);case FfiCommand_SyncPreview() when syncPreview != null:
return syncPreview(_that);case FfiCommand_SyncRun() when syncRun != null:
return syncRun(_that);case FfiCommand_SyncCancel() when syncCancel != null:
return syncCancel(_that);case FfiCommand_PushTargets() when pushTargets != null:
return pushTargets(_that);case FfiCommand_PushCreateTarget() when pushCreateTarget != null:
return pushCreateTarget(_that);case FfiCommand_PushPlan() when pushPlan != null:
return pushPlan(_that);case FfiCommand_PushRun() when pushRun != null:
return pushRun(_that);case FfiCommand_PushCancel() when pushCancel != null:
return pushCancel(_that);case FfiCommand_PlaylistCategories() when playlistCategories != null:
return playlistCategories(_that);case FfiCommand_PlaylistList() when playlistList != null:
return playlistList(_that);case FfiCommand_PlaylistDetail() when playlistDetail != null:
return playlistDetail(_that);case FfiCommand_LeaderboardBoards() when leaderboardBoards != null:
return leaderboardBoards(_that);case FfiCommand_LeaderboardSongs() when leaderboardSongs != null:
return leaderboardSongs(_that);case FfiCommand_ArtistSongs() when artistSongs != null:
return artistSongs(_that);case FfiCommand_ArtistAlbums() when artistAlbums != null:
return artistAlbums(_that);case FfiCommand_AlbumSongs() when albumSongs != null:
return albumSongs(_that);case FfiCommand_PlaySongs() when playSongs != null:
return playSongs(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  pause,TResult Function()?  resume,TResult Function()?  toggle,TResult Function()?  stop,TResult Function( BigInt field0)?  seekMs,TResult Function( int volume)?  setVolume,TResult Function( SongDto song)?  playSong,TResult Function( SongDto song,  bool next)?  queueAdd,TResult Function( int index)?  queueRemove,TResult Function()?  queueClear,TResult Function()?  next,TResult Function()?  previous,TResult Function( String keyword,  String? source)?  search,TResult Function( String keyword,  int page)?  searchMore,TResult Function()?  libraryRefresh,TResult Function( SongDto song)?  favoritesAdd,TResult Function( SongDto song)?  favoritesRemove,TResult Function( PlaylistDto playlist)?  favoritePlaylistAdd,TResult Function( PlaylistDto playlist)?  favoritePlaylistRemove,TResult Function( SongDto song)?  historyRemove,TResult Function()?  historyClear,TResult Function( String name)?  customPlaylistCreate,TResult Function( String id,  String name)?  customPlaylistRename,TResult Function( String id)?  customPlaylistDelete,TResult Function( String id,  List<SongDto> songs)?  customPlaylistAddSongs,TResult Function( String id,  SongDto song)?  customPlaylistRemoveSong,TResult Function( String id)?  customPlaylistDetail,TResult Function()?  configGet,TResult Function( ConfigDto config)?  configUpdate,TResult Function( SongDto song)?  downloadEnqueue,TResult Function( BigInt id)?  downloadCancel,TResult Function()?  downloadClearFinished,TResult Function( String source,  String kind)?  qrLoginStart,TResult Function()?  qrLoginCancel,TResult Function( List<String> paths,  int maxDepth)?  localScan,TResult Function( String source)?  accountPlaylists,TResult Function( String source)?  accountFavorites,TResult Function( String source,  String playlistId)?  accountPlaylistDetail,TResult Function( String source)?  syncPreview,TResult Function( String source)?  syncRun,TResult Function()?  syncCancel,TResult Function( String source)?  pushTargets,TResult Function( String source,  String name)?  pushCreateTarget,TResult Function( String source,  String localName,  List<SongDto> localSongs,  bool isFavorites,  String targetKind,  String targetId,  String targetName,  int targetSongCount)?  pushPlan,TResult Function( String source)?  pushRun,TResult Function()?  pushCancel,TResult Function( String source)?  playlistCategories,TResult Function( String source,  String category,  int page)?  playlistList,TResult Function( String source,  String playlistId,  int page)?  playlistDetail,TResult Function( String source)?  leaderboardBoards,TResult Function( String source,  String boardId,  int page)?  leaderboardSongs,TResult Function( ArtistDto artist,  int page)?  artistSongs,TResult Function( ArtistDto artist,  int page)?  artistAlbums,TResult Function( AlbumDto album,  int page)?  albumSongs,TResult Function( List<SongDto> songs,  int index)?  playSongs,required TResult orElse(),}) {final _that = this;
switch (_that) {
case FfiCommand_Pause() when pause != null:
return pause();case FfiCommand_Resume() when resume != null:
return resume();case FfiCommand_Toggle() when toggle != null:
return toggle();case FfiCommand_Stop() when stop != null:
return stop();case FfiCommand_SeekMs() when seekMs != null:
return seekMs(_that.field0);case FfiCommand_SetVolume() when setVolume != null:
return setVolume(_that.volume);case FfiCommand_PlaySong() when playSong != null:
return playSong(_that.song);case FfiCommand_QueueAdd() when queueAdd != null:
return queueAdd(_that.song,_that.next);case FfiCommand_QueueRemove() when queueRemove != null:
return queueRemove(_that.index);case FfiCommand_QueueClear() when queueClear != null:
return queueClear();case FfiCommand_Next() when next != null:
return next();case FfiCommand_Previous() when previous != null:
return previous();case FfiCommand_Search() when search != null:
return search(_that.keyword,_that.source);case FfiCommand_SearchMore() when searchMore != null:
return searchMore(_that.keyword,_that.page);case FfiCommand_LibraryRefresh() when libraryRefresh != null:
return libraryRefresh();case FfiCommand_FavoritesAdd() when favoritesAdd != null:
return favoritesAdd(_that.song);case FfiCommand_FavoritesRemove() when favoritesRemove != null:
return favoritesRemove(_that.song);case FfiCommand_FavoritePlaylistAdd() when favoritePlaylistAdd != null:
return favoritePlaylistAdd(_that.playlist);case FfiCommand_FavoritePlaylistRemove() when favoritePlaylistRemove != null:
return favoritePlaylistRemove(_that.playlist);case FfiCommand_HistoryRemove() when historyRemove != null:
return historyRemove(_that.song);case FfiCommand_HistoryClear() when historyClear != null:
return historyClear();case FfiCommand_CustomPlaylistCreate() when customPlaylistCreate != null:
return customPlaylistCreate(_that.name);case FfiCommand_CustomPlaylistRename() when customPlaylistRename != null:
return customPlaylistRename(_that.id,_that.name);case FfiCommand_CustomPlaylistDelete() when customPlaylistDelete != null:
return customPlaylistDelete(_that.id);case FfiCommand_CustomPlaylistAddSongs() when customPlaylistAddSongs != null:
return customPlaylistAddSongs(_that.id,_that.songs);case FfiCommand_CustomPlaylistRemoveSong() when customPlaylistRemoveSong != null:
return customPlaylistRemoveSong(_that.id,_that.song);case FfiCommand_CustomPlaylistDetail() when customPlaylistDetail != null:
return customPlaylistDetail(_that.id);case FfiCommand_ConfigGet() when configGet != null:
return configGet();case FfiCommand_ConfigUpdate() when configUpdate != null:
return configUpdate(_that.config);case FfiCommand_DownloadEnqueue() when downloadEnqueue != null:
return downloadEnqueue(_that.song);case FfiCommand_DownloadCancel() when downloadCancel != null:
return downloadCancel(_that.id);case FfiCommand_DownloadClearFinished() when downloadClearFinished != null:
return downloadClearFinished();case FfiCommand_QrLoginStart() when qrLoginStart != null:
return qrLoginStart(_that.source,_that.kind);case FfiCommand_QrLoginCancel() when qrLoginCancel != null:
return qrLoginCancel();case FfiCommand_LocalScan() when localScan != null:
return localScan(_that.paths,_that.maxDepth);case FfiCommand_AccountPlaylists() when accountPlaylists != null:
return accountPlaylists(_that.source);case FfiCommand_AccountFavorites() when accountFavorites != null:
return accountFavorites(_that.source);case FfiCommand_AccountPlaylistDetail() when accountPlaylistDetail != null:
return accountPlaylistDetail(_that.source,_that.playlistId);case FfiCommand_SyncPreview() when syncPreview != null:
return syncPreview(_that.source);case FfiCommand_SyncRun() when syncRun != null:
return syncRun(_that.source);case FfiCommand_SyncCancel() when syncCancel != null:
return syncCancel();case FfiCommand_PushTargets() when pushTargets != null:
return pushTargets(_that.source);case FfiCommand_PushCreateTarget() when pushCreateTarget != null:
return pushCreateTarget(_that.source,_that.name);case FfiCommand_PushPlan() when pushPlan != null:
return pushPlan(_that.source,_that.localName,_that.localSongs,_that.isFavorites,_that.targetKind,_that.targetId,_that.targetName,_that.targetSongCount);case FfiCommand_PushRun() when pushRun != null:
return pushRun(_that.source);case FfiCommand_PushCancel() when pushCancel != null:
return pushCancel();case FfiCommand_PlaylistCategories() when playlistCategories != null:
return playlistCategories(_that.source);case FfiCommand_PlaylistList() when playlistList != null:
return playlistList(_that.source,_that.category,_that.page);case FfiCommand_PlaylistDetail() when playlistDetail != null:
return playlistDetail(_that.source,_that.playlistId,_that.page);case FfiCommand_LeaderboardBoards() when leaderboardBoards != null:
return leaderboardBoards(_that.source);case FfiCommand_LeaderboardSongs() when leaderboardSongs != null:
return leaderboardSongs(_that.source,_that.boardId,_that.page);case FfiCommand_ArtistSongs() when artistSongs != null:
return artistSongs(_that.artist,_that.page);case FfiCommand_ArtistAlbums() when artistAlbums != null:
return artistAlbums(_that.artist,_that.page);case FfiCommand_AlbumSongs() when albumSongs != null:
return albumSongs(_that.album,_that.page);case FfiCommand_PlaySongs() when playSongs != null:
return playSongs(_that.songs,_that.index);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  pause,required TResult Function()  resume,required TResult Function()  toggle,required TResult Function()  stop,required TResult Function( BigInt field0)  seekMs,required TResult Function( int volume)  setVolume,required TResult Function( SongDto song)  playSong,required TResult Function( SongDto song,  bool next)  queueAdd,required TResult Function( int index)  queueRemove,required TResult Function()  queueClear,required TResult Function()  next,required TResult Function()  previous,required TResult Function( String keyword,  String? source)  search,required TResult Function( String keyword,  int page)  searchMore,required TResult Function()  libraryRefresh,required TResult Function( SongDto song)  favoritesAdd,required TResult Function( SongDto song)  favoritesRemove,required TResult Function( PlaylistDto playlist)  favoritePlaylistAdd,required TResult Function( PlaylistDto playlist)  favoritePlaylistRemove,required TResult Function( SongDto song)  historyRemove,required TResult Function()  historyClear,required TResult Function( String name)  customPlaylistCreate,required TResult Function( String id,  String name)  customPlaylistRename,required TResult Function( String id)  customPlaylistDelete,required TResult Function( String id,  List<SongDto> songs)  customPlaylistAddSongs,required TResult Function( String id,  SongDto song)  customPlaylistRemoveSong,required TResult Function( String id)  customPlaylistDetail,required TResult Function()  configGet,required TResult Function( ConfigDto config)  configUpdate,required TResult Function( SongDto song)  downloadEnqueue,required TResult Function( BigInt id)  downloadCancel,required TResult Function()  downloadClearFinished,required TResult Function( String source,  String kind)  qrLoginStart,required TResult Function()  qrLoginCancel,required TResult Function( List<String> paths,  int maxDepth)  localScan,required TResult Function( String source)  accountPlaylists,required TResult Function( String source)  accountFavorites,required TResult Function( String source,  String playlistId)  accountPlaylistDetail,required TResult Function( String source)  syncPreview,required TResult Function( String source)  syncRun,required TResult Function()  syncCancel,required TResult Function( String source)  pushTargets,required TResult Function( String source,  String name)  pushCreateTarget,required TResult Function( String source,  String localName,  List<SongDto> localSongs,  bool isFavorites,  String targetKind,  String targetId,  String targetName,  int targetSongCount)  pushPlan,required TResult Function( String source)  pushRun,required TResult Function()  pushCancel,required TResult Function( String source)  playlistCategories,required TResult Function( String source,  String category,  int page)  playlistList,required TResult Function( String source,  String playlistId,  int page)  playlistDetail,required TResult Function( String source)  leaderboardBoards,required TResult Function( String source,  String boardId,  int page)  leaderboardSongs,required TResult Function( ArtistDto artist,  int page)  artistSongs,required TResult Function( ArtistDto artist,  int page)  artistAlbums,required TResult Function( AlbumDto album,  int page)  albumSongs,required TResult Function( List<SongDto> songs,  int index)  playSongs,}) {final _that = this;
switch (_that) {
case FfiCommand_Pause():
return pause();case FfiCommand_Resume():
return resume();case FfiCommand_Toggle():
return toggle();case FfiCommand_Stop():
return stop();case FfiCommand_SeekMs():
return seekMs(_that.field0);case FfiCommand_SetVolume():
return setVolume(_that.volume);case FfiCommand_PlaySong():
return playSong(_that.song);case FfiCommand_QueueAdd():
return queueAdd(_that.song,_that.next);case FfiCommand_QueueRemove():
return queueRemove(_that.index);case FfiCommand_QueueClear():
return queueClear();case FfiCommand_Next():
return next();case FfiCommand_Previous():
return previous();case FfiCommand_Search():
return search(_that.keyword,_that.source);case FfiCommand_SearchMore():
return searchMore(_that.keyword,_that.page);case FfiCommand_LibraryRefresh():
return libraryRefresh();case FfiCommand_FavoritesAdd():
return favoritesAdd(_that.song);case FfiCommand_FavoritesRemove():
return favoritesRemove(_that.song);case FfiCommand_FavoritePlaylistAdd():
return favoritePlaylistAdd(_that.playlist);case FfiCommand_FavoritePlaylistRemove():
return favoritePlaylistRemove(_that.playlist);case FfiCommand_HistoryRemove():
return historyRemove(_that.song);case FfiCommand_HistoryClear():
return historyClear();case FfiCommand_CustomPlaylistCreate():
return customPlaylistCreate(_that.name);case FfiCommand_CustomPlaylistRename():
return customPlaylistRename(_that.id,_that.name);case FfiCommand_CustomPlaylistDelete():
return customPlaylistDelete(_that.id);case FfiCommand_CustomPlaylistAddSongs():
return customPlaylistAddSongs(_that.id,_that.songs);case FfiCommand_CustomPlaylistRemoveSong():
return customPlaylistRemoveSong(_that.id,_that.song);case FfiCommand_CustomPlaylistDetail():
return customPlaylistDetail(_that.id);case FfiCommand_ConfigGet():
return configGet();case FfiCommand_ConfigUpdate():
return configUpdate(_that.config);case FfiCommand_DownloadEnqueue():
return downloadEnqueue(_that.song);case FfiCommand_DownloadCancel():
return downloadCancel(_that.id);case FfiCommand_DownloadClearFinished():
return downloadClearFinished();case FfiCommand_QrLoginStart():
return qrLoginStart(_that.source,_that.kind);case FfiCommand_QrLoginCancel():
return qrLoginCancel();case FfiCommand_LocalScan():
return localScan(_that.paths,_that.maxDepth);case FfiCommand_AccountPlaylists():
return accountPlaylists(_that.source);case FfiCommand_AccountFavorites():
return accountFavorites(_that.source);case FfiCommand_AccountPlaylistDetail():
return accountPlaylistDetail(_that.source,_that.playlistId);case FfiCommand_SyncPreview():
return syncPreview(_that.source);case FfiCommand_SyncRun():
return syncRun(_that.source);case FfiCommand_SyncCancel():
return syncCancel();case FfiCommand_PushTargets():
return pushTargets(_that.source);case FfiCommand_PushCreateTarget():
return pushCreateTarget(_that.source,_that.name);case FfiCommand_PushPlan():
return pushPlan(_that.source,_that.localName,_that.localSongs,_that.isFavorites,_that.targetKind,_that.targetId,_that.targetName,_that.targetSongCount);case FfiCommand_PushRun():
return pushRun(_that.source);case FfiCommand_PushCancel():
return pushCancel();case FfiCommand_PlaylistCategories():
return playlistCategories(_that.source);case FfiCommand_PlaylistList():
return playlistList(_that.source,_that.category,_that.page);case FfiCommand_PlaylistDetail():
return playlistDetail(_that.source,_that.playlistId,_that.page);case FfiCommand_LeaderboardBoards():
return leaderboardBoards(_that.source);case FfiCommand_LeaderboardSongs():
return leaderboardSongs(_that.source,_that.boardId,_that.page);case FfiCommand_ArtistSongs():
return artistSongs(_that.artist,_that.page);case FfiCommand_ArtistAlbums():
return artistAlbums(_that.artist,_that.page);case FfiCommand_AlbumSongs():
return albumSongs(_that.album,_that.page);case FfiCommand_PlaySongs():
return playSongs(_that.songs,_that.index);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  pause,TResult? Function()?  resume,TResult? Function()?  toggle,TResult? Function()?  stop,TResult? Function( BigInt field0)?  seekMs,TResult? Function( int volume)?  setVolume,TResult? Function( SongDto song)?  playSong,TResult? Function( SongDto song,  bool next)?  queueAdd,TResult? Function( int index)?  queueRemove,TResult? Function()?  queueClear,TResult? Function()?  next,TResult? Function()?  previous,TResult? Function( String keyword,  String? source)?  search,TResult? Function( String keyword,  int page)?  searchMore,TResult? Function()?  libraryRefresh,TResult? Function( SongDto song)?  favoritesAdd,TResult? Function( SongDto song)?  favoritesRemove,TResult? Function( PlaylistDto playlist)?  favoritePlaylistAdd,TResult? Function( PlaylistDto playlist)?  favoritePlaylistRemove,TResult? Function( SongDto song)?  historyRemove,TResult? Function()?  historyClear,TResult? Function( String name)?  customPlaylistCreate,TResult? Function( String id,  String name)?  customPlaylistRename,TResult? Function( String id)?  customPlaylistDelete,TResult? Function( String id,  List<SongDto> songs)?  customPlaylistAddSongs,TResult? Function( String id,  SongDto song)?  customPlaylistRemoveSong,TResult? Function( String id)?  customPlaylistDetail,TResult? Function()?  configGet,TResult? Function( ConfigDto config)?  configUpdate,TResult? Function( SongDto song)?  downloadEnqueue,TResult? Function( BigInt id)?  downloadCancel,TResult? Function()?  downloadClearFinished,TResult? Function( String source,  String kind)?  qrLoginStart,TResult? Function()?  qrLoginCancel,TResult? Function( List<String> paths,  int maxDepth)?  localScan,TResult? Function( String source)?  accountPlaylists,TResult? Function( String source)?  accountFavorites,TResult? Function( String source,  String playlistId)?  accountPlaylistDetail,TResult? Function( String source)?  syncPreview,TResult? Function( String source)?  syncRun,TResult? Function()?  syncCancel,TResult? Function( String source)?  pushTargets,TResult? Function( String source,  String name)?  pushCreateTarget,TResult? Function( String source,  String localName,  List<SongDto> localSongs,  bool isFavorites,  String targetKind,  String targetId,  String targetName,  int targetSongCount)?  pushPlan,TResult? Function( String source)?  pushRun,TResult? Function()?  pushCancel,TResult? Function( String source)?  playlistCategories,TResult? Function( String source,  String category,  int page)?  playlistList,TResult? Function( String source,  String playlistId,  int page)?  playlistDetail,TResult? Function( String source)?  leaderboardBoards,TResult? Function( String source,  String boardId,  int page)?  leaderboardSongs,TResult? Function( ArtistDto artist,  int page)?  artistSongs,TResult? Function( ArtistDto artist,  int page)?  artistAlbums,TResult? Function( AlbumDto album,  int page)?  albumSongs,TResult? Function( List<SongDto> songs,  int index)?  playSongs,}) {final _that = this;
switch (_that) {
case FfiCommand_Pause() when pause != null:
return pause();case FfiCommand_Resume() when resume != null:
return resume();case FfiCommand_Toggle() when toggle != null:
return toggle();case FfiCommand_Stop() when stop != null:
return stop();case FfiCommand_SeekMs() when seekMs != null:
return seekMs(_that.field0);case FfiCommand_SetVolume() when setVolume != null:
return setVolume(_that.volume);case FfiCommand_PlaySong() when playSong != null:
return playSong(_that.song);case FfiCommand_QueueAdd() when queueAdd != null:
return queueAdd(_that.song,_that.next);case FfiCommand_QueueRemove() when queueRemove != null:
return queueRemove(_that.index);case FfiCommand_QueueClear() when queueClear != null:
return queueClear();case FfiCommand_Next() when next != null:
return next();case FfiCommand_Previous() when previous != null:
return previous();case FfiCommand_Search() when search != null:
return search(_that.keyword,_that.source);case FfiCommand_SearchMore() when searchMore != null:
return searchMore(_that.keyword,_that.page);case FfiCommand_LibraryRefresh() when libraryRefresh != null:
return libraryRefresh();case FfiCommand_FavoritesAdd() when favoritesAdd != null:
return favoritesAdd(_that.song);case FfiCommand_FavoritesRemove() when favoritesRemove != null:
return favoritesRemove(_that.song);case FfiCommand_FavoritePlaylistAdd() when favoritePlaylistAdd != null:
return favoritePlaylistAdd(_that.playlist);case FfiCommand_FavoritePlaylistRemove() when favoritePlaylistRemove != null:
return favoritePlaylistRemove(_that.playlist);case FfiCommand_HistoryRemove() when historyRemove != null:
return historyRemove(_that.song);case FfiCommand_HistoryClear() when historyClear != null:
return historyClear();case FfiCommand_CustomPlaylistCreate() when customPlaylistCreate != null:
return customPlaylistCreate(_that.name);case FfiCommand_CustomPlaylistRename() when customPlaylistRename != null:
return customPlaylistRename(_that.id,_that.name);case FfiCommand_CustomPlaylistDelete() when customPlaylistDelete != null:
return customPlaylistDelete(_that.id);case FfiCommand_CustomPlaylistAddSongs() when customPlaylistAddSongs != null:
return customPlaylistAddSongs(_that.id,_that.songs);case FfiCommand_CustomPlaylistRemoveSong() when customPlaylistRemoveSong != null:
return customPlaylistRemoveSong(_that.id,_that.song);case FfiCommand_CustomPlaylistDetail() when customPlaylistDetail != null:
return customPlaylistDetail(_that.id);case FfiCommand_ConfigGet() when configGet != null:
return configGet();case FfiCommand_ConfigUpdate() when configUpdate != null:
return configUpdate(_that.config);case FfiCommand_DownloadEnqueue() when downloadEnqueue != null:
return downloadEnqueue(_that.song);case FfiCommand_DownloadCancel() when downloadCancel != null:
return downloadCancel(_that.id);case FfiCommand_DownloadClearFinished() when downloadClearFinished != null:
return downloadClearFinished();case FfiCommand_QrLoginStart() when qrLoginStart != null:
return qrLoginStart(_that.source,_that.kind);case FfiCommand_QrLoginCancel() when qrLoginCancel != null:
return qrLoginCancel();case FfiCommand_LocalScan() when localScan != null:
return localScan(_that.paths,_that.maxDepth);case FfiCommand_AccountPlaylists() when accountPlaylists != null:
return accountPlaylists(_that.source);case FfiCommand_AccountFavorites() when accountFavorites != null:
return accountFavorites(_that.source);case FfiCommand_AccountPlaylistDetail() when accountPlaylistDetail != null:
return accountPlaylistDetail(_that.source,_that.playlistId);case FfiCommand_SyncPreview() when syncPreview != null:
return syncPreview(_that.source);case FfiCommand_SyncRun() when syncRun != null:
return syncRun(_that.source);case FfiCommand_SyncCancel() when syncCancel != null:
return syncCancel();case FfiCommand_PushTargets() when pushTargets != null:
return pushTargets(_that.source);case FfiCommand_PushCreateTarget() when pushCreateTarget != null:
return pushCreateTarget(_that.source,_that.name);case FfiCommand_PushPlan() when pushPlan != null:
return pushPlan(_that.source,_that.localName,_that.localSongs,_that.isFavorites,_that.targetKind,_that.targetId,_that.targetName,_that.targetSongCount);case FfiCommand_PushRun() when pushRun != null:
return pushRun(_that.source);case FfiCommand_PushCancel() when pushCancel != null:
return pushCancel();case FfiCommand_PlaylistCategories() when playlistCategories != null:
return playlistCategories(_that.source);case FfiCommand_PlaylistList() when playlistList != null:
return playlistList(_that.source,_that.category,_that.page);case FfiCommand_PlaylistDetail() when playlistDetail != null:
return playlistDetail(_that.source,_that.playlistId,_that.page);case FfiCommand_LeaderboardBoards() when leaderboardBoards != null:
return leaderboardBoards(_that.source);case FfiCommand_LeaderboardSongs() when leaderboardSongs != null:
return leaderboardSongs(_that.source,_that.boardId,_that.page);case FfiCommand_ArtistSongs() when artistSongs != null:
return artistSongs(_that.artist,_that.page);case FfiCommand_ArtistAlbums() when artistAlbums != null:
return artistAlbums(_that.artist,_that.page);case FfiCommand_AlbumSongs() when albumSongs != null:
return albumSongs(_that.album,_that.page);case FfiCommand_PlaySongs() when playSongs != null:
return playSongs(_that.songs,_that.index);case _:
  return null;

}
}

}

/// @nodoc


class FfiCommand_Pause extends FfiCommand {
  const FfiCommand_Pause(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_Pause);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FfiCommand.pause()';
}


}




/// @nodoc


class FfiCommand_Resume extends FfiCommand {
  const FfiCommand_Resume(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_Resume);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FfiCommand.resume()';
}


}




/// @nodoc


class FfiCommand_Toggle extends FfiCommand {
  const FfiCommand_Toggle(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_Toggle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FfiCommand.toggle()';
}


}




/// @nodoc


class FfiCommand_Stop extends FfiCommand {
  const FfiCommand_Stop(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_Stop);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FfiCommand.stop()';
}


}




/// @nodoc


class FfiCommand_SeekMs extends FfiCommand {
  const FfiCommand_SeekMs(this.field0): super._();
  

 final  BigInt field0;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_SeekMsCopyWith<FfiCommand_SeekMs> get copyWith => _$FfiCommand_SeekMsCopyWithImpl<FfiCommand_SeekMs>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_SeekMs&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'FfiCommand.seekMs(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_SeekMsCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_SeekMsCopyWith(FfiCommand_SeekMs value, $Res Function(FfiCommand_SeekMs) _then) = _$FfiCommand_SeekMsCopyWithImpl;
@useResult
$Res call({
 BigInt field0
});




}
/// @nodoc
class _$FfiCommand_SeekMsCopyWithImpl<$Res>
    implements $FfiCommand_SeekMsCopyWith<$Res> {
  _$FfiCommand_SeekMsCopyWithImpl(this._self, this._then);

  final FfiCommand_SeekMs _self;
  final $Res Function(FfiCommand_SeekMs) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(FfiCommand_SeekMs(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as BigInt,
  ));
}


}

/// @nodoc


class FfiCommand_SetVolume extends FfiCommand {
  const FfiCommand_SetVolume({required this.volume}): super._();
  

 final  int volume;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_SetVolumeCopyWith<FfiCommand_SetVolume> get copyWith => _$FfiCommand_SetVolumeCopyWithImpl<FfiCommand_SetVolume>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_SetVolume&&(identical(other.volume, volume) || other.volume == volume));
}


@override
int get hashCode => Object.hash(runtimeType,volume);

@override
String toString() {
  return 'FfiCommand.setVolume(volume: $volume)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_SetVolumeCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_SetVolumeCopyWith(FfiCommand_SetVolume value, $Res Function(FfiCommand_SetVolume) _then) = _$FfiCommand_SetVolumeCopyWithImpl;
@useResult
$Res call({
 int volume
});




}
/// @nodoc
class _$FfiCommand_SetVolumeCopyWithImpl<$Res>
    implements $FfiCommand_SetVolumeCopyWith<$Res> {
  _$FfiCommand_SetVolumeCopyWithImpl(this._self, this._then);

  final FfiCommand_SetVolume _self;
  final $Res Function(FfiCommand_SetVolume) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? volume = null,}) {
  return _then(FfiCommand_SetVolume(
volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class FfiCommand_PlaySong extends FfiCommand {
  const FfiCommand_PlaySong({required this.song}): super._();
  

 final  SongDto song;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_PlaySongCopyWith<FfiCommand_PlaySong> get copyWith => _$FfiCommand_PlaySongCopyWithImpl<FfiCommand_PlaySong>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_PlaySong&&(identical(other.song, song) || other.song == song));
}


@override
int get hashCode => Object.hash(runtimeType,song);

@override
String toString() {
  return 'FfiCommand.playSong(song: $song)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_PlaySongCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_PlaySongCopyWith(FfiCommand_PlaySong value, $Res Function(FfiCommand_PlaySong) _then) = _$FfiCommand_PlaySongCopyWithImpl;
@useResult
$Res call({
 SongDto song
});




}
/// @nodoc
class _$FfiCommand_PlaySongCopyWithImpl<$Res>
    implements $FfiCommand_PlaySongCopyWith<$Res> {
  _$FfiCommand_PlaySongCopyWithImpl(this._self, this._then);

  final FfiCommand_PlaySong _self;
  final $Res Function(FfiCommand_PlaySong) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? song = null,}) {
  return _then(FfiCommand_PlaySong(
song: null == song ? _self.song : song // ignore: cast_nullable_to_non_nullable
as SongDto,
  ));
}


}

/// @nodoc


class FfiCommand_QueueAdd extends FfiCommand {
  const FfiCommand_QueueAdd({required this.song, required this.next}): super._();
  

 final  SongDto song;
 final  bool next;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_QueueAddCopyWith<FfiCommand_QueueAdd> get copyWith => _$FfiCommand_QueueAddCopyWithImpl<FfiCommand_QueueAdd>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_QueueAdd&&(identical(other.song, song) || other.song == song)&&(identical(other.next, next) || other.next == next));
}


@override
int get hashCode => Object.hash(runtimeType,song,next);

@override
String toString() {
  return 'FfiCommand.queueAdd(song: $song, next: $next)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_QueueAddCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_QueueAddCopyWith(FfiCommand_QueueAdd value, $Res Function(FfiCommand_QueueAdd) _then) = _$FfiCommand_QueueAddCopyWithImpl;
@useResult
$Res call({
 SongDto song, bool next
});




}
/// @nodoc
class _$FfiCommand_QueueAddCopyWithImpl<$Res>
    implements $FfiCommand_QueueAddCopyWith<$Res> {
  _$FfiCommand_QueueAddCopyWithImpl(this._self, this._then);

  final FfiCommand_QueueAdd _self;
  final $Res Function(FfiCommand_QueueAdd) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? song = null,Object? next = null,}) {
  return _then(FfiCommand_QueueAdd(
song: null == song ? _self.song : song // ignore: cast_nullable_to_non_nullable
as SongDto,next: null == next ? _self.next : next // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class FfiCommand_QueueRemove extends FfiCommand {
  const FfiCommand_QueueRemove({required this.index}): super._();
  

 final  int index;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_QueueRemoveCopyWith<FfiCommand_QueueRemove> get copyWith => _$FfiCommand_QueueRemoveCopyWithImpl<FfiCommand_QueueRemove>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_QueueRemove&&(identical(other.index, index) || other.index == index));
}


@override
int get hashCode => Object.hash(runtimeType,index);

@override
String toString() {
  return 'FfiCommand.queueRemove(index: $index)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_QueueRemoveCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_QueueRemoveCopyWith(FfiCommand_QueueRemove value, $Res Function(FfiCommand_QueueRemove) _then) = _$FfiCommand_QueueRemoveCopyWithImpl;
@useResult
$Res call({
 int index
});




}
/// @nodoc
class _$FfiCommand_QueueRemoveCopyWithImpl<$Res>
    implements $FfiCommand_QueueRemoveCopyWith<$Res> {
  _$FfiCommand_QueueRemoveCopyWithImpl(this._self, this._then);

  final FfiCommand_QueueRemove _self;
  final $Res Function(FfiCommand_QueueRemove) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? index = null,}) {
  return _then(FfiCommand_QueueRemove(
index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class FfiCommand_QueueClear extends FfiCommand {
  const FfiCommand_QueueClear(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_QueueClear);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FfiCommand.queueClear()';
}


}




/// @nodoc


class FfiCommand_Next extends FfiCommand {
  const FfiCommand_Next(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_Next);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FfiCommand.next()';
}


}




/// @nodoc


class FfiCommand_Previous extends FfiCommand {
  const FfiCommand_Previous(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_Previous);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FfiCommand.previous()';
}


}




/// @nodoc


class FfiCommand_Search extends FfiCommand {
  const FfiCommand_Search({required this.keyword, this.source}): super._();
  

 final  String keyword;
/// 可选音源过滤；None 为聚合搜索。不合法的 id 报错。
 final  String? source;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_SearchCopyWith<FfiCommand_Search> get copyWith => _$FfiCommand_SearchCopyWithImpl<FfiCommand_Search>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_Search&&(identical(other.keyword, keyword) || other.keyword == keyword)&&(identical(other.source, source) || other.source == source));
}


@override
int get hashCode => Object.hash(runtimeType,keyword,source);

@override
String toString() {
  return 'FfiCommand.search(keyword: $keyword, source: $source)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_SearchCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_SearchCopyWith(FfiCommand_Search value, $Res Function(FfiCommand_Search) _then) = _$FfiCommand_SearchCopyWithImpl;
@useResult
$Res call({
 String keyword, String? source
});




}
/// @nodoc
class _$FfiCommand_SearchCopyWithImpl<$Res>
    implements $FfiCommand_SearchCopyWith<$Res> {
  _$FfiCommand_SearchCopyWithImpl(this._self, this._then);

  final FfiCommand_Search _self;
  final $Res Function(FfiCommand_Search) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? keyword = null,Object? source = freezed,}) {
  return _then(FfiCommand_Search(
keyword: null == keyword ? _self.keyword : keyword // ignore: cast_nullable_to_non_nullable
as String,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class FfiCommand_SearchMore extends FfiCommand {
  const FfiCommand_SearchMore({required this.keyword, required this.page}): super._();
  

 final  String keyword;
 final  int page;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_SearchMoreCopyWith<FfiCommand_SearchMore> get copyWith => _$FfiCommand_SearchMoreCopyWithImpl<FfiCommand_SearchMore>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_SearchMore&&(identical(other.keyword, keyword) || other.keyword == keyword)&&(identical(other.page, page) || other.page == page));
}


@override
int get hashCode => Object.hash(runtimeType,keyword,page);

@override
String toString() {
  return 'FfiCommand.searchMore(keyword: $keyword, page: $page)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_SearchMoreCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_SearchMoreCopyWith(FfiCommand_SearchMore value, $Res Function(FfiCommand_SearchMore) _then) = _$FfiCommand_SearchMoreCopyWithImpl;
@useResult
$Res call({
 String keyword, int page
});




}
/// @nodoc
class _$FfiCommand_SearchMoreCopyWithImpl<$Res>
    implements $FfiCommand_SearchMoreCopyWith<$Res> {
  _$FfiCommand_SearchMoreCopyWithImpl(this._self, this._then);

  final FfiCommand_SearchMore _self;
  final $Res Function(FfiCommand_SearchMore) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? keyword = null,Object? page = null,}) {
  return _then(FfiCommand_SearchMore(
keyword: null == keyword ? _self.keyword : keyword // ignore: cast_nullable_to_non_nullable
as String,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class FfiCommand_LibraryRefresh extends FfiCommand {
  const FfiCommand_LibraryRefresh(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_LibraryRefresh);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FfiCommand.libraryRefresh()';
}


}




/// @nodoc


class FfiCommand_FavoritesAdd extends FfiCommand {
  const FfiCommand_FavoritesAdd({required this.song}): super._();
  

 final  SongDto song;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_FavoritesAddCopyWith<FfiCommand_FavoritesAdd> get copyWith => _$FfiCommand_FavoritesAddCopyWithImpl<FfiCommand_FavoritesAdd>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_FavoritesAdd&&(identical(other.song, song) || other.song == song));
}


@override
int get hashCode => Object.hash(runtimeType,song);

@override
String toString() {
  return 'FfiCommand.favoritesAdd(song: $song)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_FavoritesAddCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_FavoritesAddCopyWith(FfiCommand_FavoritesAdd value, $Res Function(FfiCommand_FavoritesAdd) _then) = _$FfiCommand_FavoritesAddCopyWithImpl;
@useResult
$Res call({
 SongDto song
});




}
/// @nodoc
class _$FfiCommand_FavoritesAddCopyWithImpl<$Res>
    implements $FfiCommand_FavoritesAddCopyWith<$Res> {
  _$FfiCommand_FavoritesAddCopyWithImpl(this._self, this._then);

  final FfiCommand_FavoritesAdd _self;
  final $Res Function(FfiCommand_FavoritesAdd) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? song = null,}) {
  return _then(FfiCommand_FavoritesAdd(
song: null == song ? _self.song : song // ignore: cast_nullable_to_non_nullable
as SongDto,
  ));
}


}

/// @nodoc


class FfiCommand_FavoritesRemove extends FfiCommand {
  const FfiCommand_FavoritesRemove({required this.song}): super._();
  

 final  SongDto song;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_FavoritesRemoveCopyWith<FfiCommand_FavoritesRemove> get copyWith => _$FfiCommand_FavoritesRemoveCopyWithImpl<FfiCommand_FavoritesRemove>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_FavoritesRemove&&(identical(other.song, song) || other.song == song));
}


@override
int get hashCode => Object.hash(runtimeType,song);

@override
String toString() {
  return 'FfiCommand.favoritesRemove(song: $song)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_FavoritesRemoveCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_FavoritesRemoveCopyWith(FfiCommand_FavoritesRemove value, $Res Function(FfiCommand_FavoritesRemove) _then) = _$FfiCommand_FavoritesRemoveCopyWithImpl;
@useResult
$Res call({
 SongDto song
});




}
/// @nodoc
class _$FfiCommand_FavoritesRemoveCopyWithImpl<$Res>
    implements $FfiCommand_FavoritesRemoveCopyWith<$Res> {
  _$FfiCommand_FavoritesRemoveCopyWithImpl(this._self, this._then);

  final FfiCommand_FavoritesRemove _self;
  final $Res Function(FfiCommand_FavoritesRemove) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? song = null,}) {
  return _then(FfiCommand_FavoritesRemove(
song: null == song ? _self.song : song // ignore: cast_nullable_to_non_nullable
as SongDto,
  ));
}


}

/// @nodoc


class FfiCommand_FavoritePlaylistAdd extends FfiCommand {
  const FfiCommand_FavoritePlaylistAdd({required this.playlist}): super._();
  

 final  PlaylistDto playlist;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_FavoritePlaylistAddCopyWith<FfiCommand_FavoritePlaylistAdd> get copyWith => _$FfiCommand_FavoritePlaylistAddCopyWithImpl<FfiCommand_FavoritePlaylistAdd>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_FavoritePlaylistAdd&&(identical(other.playlist, playlist) || other.playlist == playlist));
}


@override
int get hashCode => Object.hash(runtimeType,playlist);

@override
String toString() {
  return 'FfiCommand.favoritePlaylistAdd(playlist: $playlist)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_FavoritePlaylistAddCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_FavoritePlaylistAddCopyWith(FfiCommand_FavoritePlaylistAdd value, $Res Function(FfiCommand_FavoritePlaylistAdd) _then) = _$FfiCommand_FavoritePlaylistAddCopyWithImpl;
@useResult
$Res call({
 PlaylistDto playlist
});




}
/// @nodoc
class _$FfiCommand_FavoritePlaylistAddCopyWithImpl<$Res>
    implements $FfiCommand_FavoritePlaylistAddCopyWith<$Res> {
  _$FfiCommand_FavoritePlaylistAddCopyWithImpl(this._self, this._then);

  final FfiCommand_FavoritePlaylistAdd _self;
  final $Res Function(FfiCommand_FavoritePlaylistAdd) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? playlist = null,}) {
  return _then(FfiCommand_FavoritePlaylistAdd(
playlist: null == playlist ? _self.playlist : playlist // ignore: cast_nullable_to_non_nullable
as PlaylistDto,
  ));
}


}

/// @nodoc


class FfiCommand_FavoritePlaylistRemove extends FfiCommand {
  const FfiCommand_FavoritePlaylistRemove({required this.playlist}): super._();
  

 final  PlaylistDto playlist;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_FavoritePlaylistRemoveCopyWith<FfiCommand_FavoritePlaylistRemove> get copyWith => _$FfiCommand_FavoritePlaylistRemoveCopyWithImpl<FfiCommand_FavoritePlaylistRemove>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_FavoritePlaylistRemove&&(identical(other.playlist, playlist) || other.playlist == playlist));
}


@override
int get hashCode => Object.hash(runtimeType,playlist);

@override
String toString() {
  return 'FfiCommand.favoritePlaylistRemove(playlist: $playlist)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_FavoritePlaylistRemoveCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_FavoritePlaylistRemoveCopyWith(FfiCommand_FavoritePlaylistRemove value, $Res Function(FfiCommand_FavoritePlaylistRemove) _then) = _$FfiCommand_FavoritePlaylistRemoveCopyWithImpl;
@useResult
$Res call({
 PlaylistDto playlist
});




}
/// @nodoc
class _$FfiCommand_FavoritePlaylistRemoveCopyWithImpl<$Res>
    implements $FfiCommand_FavoritePlaylistRemoveCopyWith<$Res> {
  _$FfiCommand_FavoritePlaylistRemoveCopyWithImpl(this._self, this._then);

  final FfiCommand_FavoritePlaylistRemove _self;
  final $Res Function(FfiCommand_FavoritePlaylistRemove) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? playlist = null,}) {
  return _then(FfiCommand_FavoritePlaylistRemove(
playlist: null == playlist ? _self.playlist : playlist // ignore: cast_nullable_to_non_nullable
as PlaylistDto,
  ));
}


}

/// @nodoc


class FfiCommand_HistoryRemove extends FfiCommand {
  const FfiCommand_HistoryRemove({required this.song}): super._();
  

 final  SongDto song;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_HistoryRemoveCopyWith<FfiCommand_HistoryRemove> get copyWith => _$FfiCommand_HistoryRemoveCopyWithImpl<FfiCommand_HistoryRemove>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_HistoryRemove&&(identical(other.song, song) || other.song == song));
}


@override
int get hashCode => Object.hash(runtimeType,song);

@override
String toString() {
  return 'FfiCommand.historyRemove(song: $song)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_HistoryRemoveCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_HistoryRemoveCopyWith(FfiCommand_HistoryRemove value, $Res Function(FfiCommand_HistoryRemove) _then) = _$FfiCommand_HistoryRemoveCopyWithImpl;
@useResult
$Res call({
 SongDto song
});




}
/// @nodoc
class _$FfiCommand_HistoryRemoveCopyWithImpl<$Res>
    implements $FfiCommand_HistoryRemoveCopyWith<$Res> {
  _$FfiCommand_HistoryRemoveCopyWithImpl(this._self, this._then);

  final FfiCommand_HistoryRemove _self;
  final $Res Function(FfiCommand_HistoryRemove) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? song = null,}) {
  return _then(FfiCommand_HistoryRemove(
song: null == song ? _self.song : song // ignore: cast_nullable_to_non_nullable
as SongDto,
  ));
}


}

/// @nodoc


class FfiCommand_HistoryClear extends FfiCommand {
  const FfiCommand_HistoryClear(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_HistoryClear);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FfiCommand.historyClear()';
}


}




/// @nodoc


class FfiCommand_CustomPlaylistCreate extends FfiCommand {
  const FfiCommand_CustomPlaylistCreate({required this.name}): super._();
  

 final  String name;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_CustomPlaylistCreateCopyWith<FfiCommand_CustomPlaylistCreate> get copyWith => _$FfiCommand_CustomPlaylistCreateCopyWithImpl<FfiCommand_CustomPlaylistCreate>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_CustomPlaylistCreate&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode => Object.hash(runtimeType,name);

@override
String toString() {
  return 'FfiCommand.customPlaylistCreate(name: $name)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_CustomPlaylistCreateCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_CustomPlaylistCreateCopyWith(FfiCommand_CustomPlaylistCreate value, $Res Function(FfiCommand_CustomPlaylistCreate) _then) = _$FfiCommand_CustomPlaylistCreateCopyWithImpl;
@useResult
$Res call({
 String name
});




}
/// @nodoc
class _$FfiCommand_CustomPlaylistCreateCopyWithImpl<$Res>
    implements $FfiCommand_CustomPlaylistCreateCopyWith<$Res> {
  _$FfiCommand_CustomPlaylistCreateCopyWithImpl(this._self, this._then);

  final FfiCommand_CustomPlaylistCreate _self;
  final $Res Function(FfiCommand_CustomPlaylistCreate) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? name = null,}) {
  return _then(FfiCommand_CustomPlaylistCreate(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class FfiCommand_CustomPlaylistRename extends FfiCommand {
  const FfiCommand_CustomPlaylistRename({required this.id, required this.name}): super._();
  

 final  String id;
 final  String name;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_CustomPlaylistRenameCopyWith<FfiCommand_CustomPlaylistRename> get copyWith => _$FfiCommand_CustomPlaylistRenameCopyWithImpl<FfiCommand_CustomPlaylistRename>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_CustomPlaylistRename&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode => Object.hash(runtimeType,id,name);

@override
String toString() {
  return 'FfiCommand.customPlaylistRename(id: $id, name: $name)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_CustomPlaylistRenameCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_CustomPlaylistRenameCopyWith(FfiCommand_CustomPlaylistRename value, $Res Function(FfiCommand_CustomPlaylistRename) _then) = _$FfiCommand_CustomPlaylistRenameCopyWithImpl;
@useResult
$Res call({
 String id, String name
});




}
/// @nodoc
class _$FfiCommand_CustomPlaylistRenameCopyWithImpl<$Res>
    implements $FfiCommand_CustomPlaylistRenameCopyWith<$Res> {
  _$FfiCommand_CustomPlaylistRenameCopyWithImpl(this._self, this._then);

  final FfiCommand_CustomPlaylistRename _self;
  final $Res Function(FfiCommand_CustomPlaylistRename) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,}) {
  return _then(FfiCommand_CustomPlaylistRename(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class FfiCommand_CustomPlaylistDelete extends FfiCommand {
  const FfiCommand_CustomPlaylistDelete({required this.id}): super._();
  

 final  String id;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_CustomPlaylistDeleteCopyWith<FfiCommand_CustomPlaylistDelete> get copyWith => _$FfiCommand_CustomPlaylistDeleteCopyWithImpl<FfiCommand_CustomPlaylistDelete>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_CustomPlaylistDelete&&(identical(other.id, id) || other.id == id));
}


@override
int get hashCode => Object.hash(runtimeType,id);

@override
String toString() {
  return 'FfiCommand.customPlaylistDelete(id: $id)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_CustomPlaylistDeleteCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_CustomPlaylistDeleteCopyWith(FfiCommand_CustomPlaylistDelete value, $Res Function(FfiCommand_CustomPlaylistDelete) _then) = _$FfiCommand_CustomPlaylistDeleteCopyWithImpl;
@useResult
$Res call({
 String id
});




}
/// @nodoc
class _$FfiCommand_CustomPlaylistDeleteCopyWithImpl<$Res>
    implements $FfiCommand_CustomPlaylistDeleteCopyWith<$Res> {
  _$FfiCommand_CustomPlaylistDeleteCopyWithImpl(this._self, this._then);

  final FfiCommand_CustomPlaylistDelete _self;
  final $Res Function(FfiCommand_CustomPlaylistDelete) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,}) {
  return _then(FfiCommand_CustomPlaylistDelete(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class FfiCommand_CustomPlaylistAddSongs extends FfiCommand {
  const FfiCommand_CustomPlaylistAddSongs({required this.id, required final  List<SongDto> songs}): _songs = songs,super._();
  

 final  String id;
 final  List<SongDto> _songs;
 List<SongDto> get songs {
  if (_songs is EqualUnmodifiableListView) return _songs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_songs);
}


/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_CustomPlaylistAddSongsCopyWith<FfiCommand_CustomPlaylistAddSongs> get copyWith => _$FfiCommand_CustomPlaylistAddSongsCopyWithImpl<FfiCommand_CustomPlaylistAddSongs>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_CustomPlaylistAddSongs&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other._songs, _songs));
}


@override
int get hashCode => Object.hash(runtimeType,id,const DeepCollectionEquality().hash(_songs));

@override
String toString() {
  return 'FfiCommand.customPlaylistAddSongs(id: $id, songs: $songs)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_CustomPlaylistAddSongsCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_CustomPlaylistAddSongsCopyWith(FfiCommand_CustomPlaylistAddSongs value, $Res Function(FfiCommand_CustomPlaylistAddSongs) _then) = _$FfiCommand_CustomPlaylistAddSongsCopyWithImpl;
@useResult
$Res call({
 String id, List<SongDto> songs
});




}
/// @nodoc
class _$FfiCommand_CustomPlaylistAddSongsCopyWithImpl<$Res>
    implements $FfiCommand_CustomPlaylistAddSongsCopyWith<$Res> {
  _$FfiCommand_CustomPlaylistAddSongsCopyWithImpl(this._self, this._then);

  final FfiCommand_CustomPlaylistAddSongs _self;
  final $Res Function(FfiCommand_CustomPlaylistAddSongs) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,Object? songs = null,}) {
  return _then(FfiCommand_CustomPlaylistAddSongs(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,songs: null == songs ? _self._songs : songs // ignore: cast_nullable_to_non_nullable
as List<SongDto>,
  ));
}


}

/// @nodoc


class FfiCommand_CustomPlaylistRemoveSong extends FfiCommand {
  const FfiCommand_CustomPlaylistRemoveSong({required this.id, required this.song}): super._();
  

 final  String id;
 final  SongDto song;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_CustomPlaylistRemoveSongCopyWith<FfiCommand_CustomPlaylistRemoveSong> get copyWith => _$FfiCommand_CustomPlaylistRemoveSongCopyWithImpl<FfiCommand_CustomPlaylistRemoveSong>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_CustomPlaylistRemoveSong&&(identical(other.id, id) || other.id == id)&&(identical(other.song, song) || other.song == song));
}


@override
int get hashCode => Object.hash(runtimeType,id,song);

@override
String toString() {
  return 'FfiCommand.customPlaylistRemoveSong(id: $id, song: $song)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_CustomPlaylistRemoveSongCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_CustomPlaylistRemoveSongCopyWith(FfiCommand_CustomPlaylistRemoveSong value, $Res Function(FfiCommand_CustomPlaylistRemoveSong) _then) = _$FfiCommand_CustomPlaylistRemoveSongCopyWithImpl;
@useResult
$Res call({
 String id, SongDto song
});




}
/// @nodoc
class _$FfiCommand_CustomPlaylistRemoveSongCopyWithImpl<$Res>
    implements $FfiCommand_CustomPlaylistRemoveSongCopyWith<$Res> {
  _$FfiCommand_CustomPlaylistRemoveSongCopyWithImpl(this._self, this._then);

  final FfiCommand_CustomPlaylistRemoveSong _self;
  final $Res Function(FfiCommand_CustomPlaylistRemoveSong) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,Object? song = null,}) {
  return _then(FfiCommand_CustomPlaylistRemoveSong(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,song: null == song ? _self.song : song // ignore: cast_nullable_to_non_nullable
as SongDto,
  ));
}


}

/// @nodoc


class FfiCommand_CustomPlaylistDetail extends FfiCommand {
  const FfiCommand_CustomPlaylistDetail({required this.id}): super._();
  

 final  String id;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_CustomPlaylistDetailCopyWith<FfiCommand_CustomPlaylistDetail> get copyWith => _$FfiCommand_CustomPlaylistDetailCopyWithImpl<FfiCommand_CustomPlaylistDetail>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_CustomPlaylistDetail&&(identical(other.id, id) || other.id == id));
}


@override
int get hashCode => Object.hash(runtimeType,id);

@override
String toString() {
  return 'FfiCommand.customPlaylistDetail(id: $id)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_CustomPlaylistDetailCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_CustomPlaylistDetailCopyWith(FfiCommand_CustomPlaylistDetail value, $Res Function(FfiCommand_CustomPlaylistDetail) _then) = _$FfiCommand_CustomPlaylistDetailCopyWithImpl;
@useResult
$Res call({
 String id
});




}
/// @nodoc
class _$FfiCommand_CustomPlaylistDetailCopyWithImpl<$Res>
    implements $FfiCommand_CustomPlaylistDetailCopyWith<$Res> {
  _$FfiCommand_CustomPlaylistDetailCopyWithImpl(this._self, this._then);

  final FfiCommand_CustomPlaylistDetail _self;
  final $Res Function(FfiCommand_CustomPlaylistDetail) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,}) {
  return _then(FfiCommand_CustomPlaylistDetail(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class FfiCommand_ConfigGet extends FfiCommand {
  const FfiCommand_ConfigGet(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_ConfigGet);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FfiCommand.configGet()';
}


}




/// @nodoc


class FfiCommand_ConfigUpdate extends FfiCommand {
  const FfiCommand_ConfigUpdate({required this.config}): super._();
  

 final  ConfigDto config;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_ConfigUpdateCopyWith<FfiCommand_ConfigUpdate> get copyWith => _$FfiCommand_ConfigUpdateCopyWithImpl<FfiCommand_ConfigUpdate>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_ConfigUpdate&&(identical(other.config, config) || other.config == config));
}


@override
int get hashCode => Object.hash(runtimeType,config);

@override
String toString() {
  return 'FfiCommand.configUpdate(config: $config)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_ConfigUpdateCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_ConfigUpdateCopyWith(FfiCommand_ConfigUpdate value, $Res Function(FfiCommand_ConfigUpdate) _then) = _$FfiCommand_ConfigUpdateCopyWithImpl;
@useResult
$Res call({
 ConfigDto config
});




}
/// @nodoc
class _$FfiCommand_ConfigUpdateCopyWithImpl<$Res>
    implements $FfiCommand_ConfigUpdateCopyWith<$Res> {
  _$FfiCommand_ConfigUpdateCopyWithImpl(this._self, this._then);

  final FfiCommand_ConfigUpdate _self;
  final $Res Function(FfiCommand_ConfigUpdate) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? config = null,}) {
  return _then(FfiCommand_ConfigUpdate(
config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as ConfigDto,
  ));
}


}

/// @nodoc


class FfiCommand_DownloadEnqueue extends FfiCommand {
  const FfiCommand_DownloadEnqueue({required this.song}): super._();
  

 final  SongDto song;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_DownloadEnqueueCopyWith<FfiCommand_DownloadEnqueue> get copyWith => _$FfiCommand_DownloadEnqueueCopyWithImpl<FfiCommand_DownloadEnqueue>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_DownloadEnqueue&&(identical(other.song, song) || other.song == song));
}


@override
int get hashCode => Object.hash(runtimeType,song);

@override
String toString() {
  return 'FfiCommand.downloadEnqueue(song: $song)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_DownloadEnqueueCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_DownloadEnqueueCopyWith(FfiCommand_DownloadEnqueue value, $Res Function(FfiCommand_DownloadEnqueue) _then) = _$FfiCommand_DownloadEnqueueCopyWithImpl;
@useResult
$Res call({
 SongDto song
});




}
/// @nodoc
class _$FfiCommand_DownloadEnqueueCopyWithImpl<$Res>
    implements $FfiCommand_DownloadEnqueueCopyWith<$Res> {
  _$FfiCommand_DownloadEnqueueCopyWithImpl(this._self, this._then);

  final FfiCommand_DownloadEnqueue _self;
  final $Res Function(FfiCommand_DownloadEnqueue) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? song = null,}) {
  return _then(FfiCommand_DownloadEnqueue(
song: null == song ? _self.song : song // ignore: cast_nullable_to_non_nullable
as SongDto,
  ));
}


}

/// @nodoc


class FfiCommand_DownloadCancel extends FfiCommand {
  const FfiCommand_DownloadCancel({required this.id}): super._();
  

 final  BigInt id;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_DownloadCancelCopyWith<FfiCommand_DownloadCancel> get copyWith => _$FfiCommand_DownloadCancelCopyWithImpl<FfiCommand_DownloadCancel>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_DownloadCancel&&(identical(other.id, id) || other.id == id));
}


@override
int get hashCode => Object.hash(runtimeType,id);

@override
String toString() {
  return 'FfiCommand.downloadCancel(id: $id)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_DownloadCancelCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_DownloadCancelCopyWith(FfiCommand_DownloadCancel value, $Res Function(FfiCommand_DownloadCancel) _then) = _$FfiCommand_DownloadCancelCopyWithImpl;
@useResult
$Res call({
 BigInt id
});




}
/// @nodoc
class _$FfiCommand_DownloadCancelCopyWithImpl<$Res>
    implements $FfiCommand_DownloadCancelCopyWith<$Res> {
  _$FfiCommand_DownloadCancelCopyWithImpl(this._self, this._then);

  final FfiCommand_DownloadCancel _self;
  final $Res Function(FfiCommand_DownloadCancel) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,}) {
  return _then(FfiCommand_DownloadCancel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as BigInt,
  ));
}


}

/// @nodoc


class FfiCommand_DownloadClearFinished extends FfiCommand {
  const FfiCommand_DownloadClearFinished(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_DownloadClearFinished);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FfiCommand.downloadClearFinished()';
}


}




/// @nodoc


class FfiCommand_QrLoginStart extends FfiCommand {
  const FfiCommand_QrLoginStart({required this.source, required this.kind}): super._();
  

 final  String source;
 final  String kind;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_QrLoginStartCopyWith<FfiCommand_QrLoginStart> get copyWith => _$FfiCommand_QrLoginStartCopyWithImpl<FfiCommand_QrLoginStart>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_QrLoginStart&&(identical(other.source, source) || other.source == source)&&(identical(other.kind, kind) || other.kind == kind));
}


@override
int get hashCode => Object.hash(runtimeType,source,kind);

@override
String toString() {
  return 'FfiCommand.qrLoginStart(source: $source, kind: $kind)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_QrLoginStartCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_QrLoginStartCopyWith(FfiCommand_QrLoginStart value, $Res Function(FfiCommand_QrLoginStart) _then) = _$FfiCommand_QrLoginStartCopyWithImpl;
@useResult
$Res call({
 String source, String kind
});




}
/// @nodoc
class _$FfiCommand_QrLoginStartCopyWithImpl<$Res>
    implements $FfiCommand_QrLoginStartCopyWith<$Res> {
  _$FfiCommand_QrLoginStartCopyWithImpl(this._self, this._then);

  final FfiCommand_QrLoginStart _self;
  final $Res Function(FfiCommand_QrLoginStart) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? source = null,Object? kind = null,}) {
  return _then(FfiCommand_QrLoginStart(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class FfiCommand_QrLoginCancel extends FfiCommand {
  const FfiCommand_QrLoginCancel(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_QrLoginCancel);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FfiCommand.qrLoginCancel()';
}


}




/// @nodoc


class FfiCommand_LocalScan extends FfiCommand {
  const FfiCommand_LocalScan({required final  List<String> paths, required this.maxDepth}): _paths = paths,super._();
  

 final  List<String> _paths;
 List<String> get paths {
  if (_paths is EqualUnmodifiableListView) return _paths;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_paths);
}

 final  int maxDepth;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_LocalScanCopyWith<FfiCommand_LocalScan> get copyWith => _$FfiCommand_LocalScanCopyWithImpl<FfiCommand_LocalScan>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_LocalScan&&const DeepCollectionEquality().equals(other._paths, _paths)&&(identical(other.maxDepth, maxDepth) || other.maxDepth == maxDepth));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_paths),maxDepth);

@override
String toString() {
  return 'FfiCommand.localScan(paths: $paths, maxDepth: $maxDepth)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_LocalScanCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_LocalScanCopyWith(FfiCommand_LocalScan value, $Res Function(FfiCommand_LocalScan) _then) = _$FfiCommand_LocalScanCopyWithImpl;
@useResult
$Res call({
 List<String> paths, int maxDepth
});




}
/// @nodoc
class _$FfiCommand_LocalScanCopyWithImpl<$Res>
    implements $FfiCommand_LocalScanCopyWith<$Res> {
  _$FfiCommand_LocalScanCopyWithImpl(this._self, this._then);

  final FfiCommand_LocalScan _self;
  final $Res Function(FfiCommand_LocalScan) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? paths = null,Object? maxDepth = null,}) {
  return _then(FfiCommand_LocalScan(
paths: null == paths ? _self._paths : paths // ignore: cast_nullable_to_non_nullable
as List<String>,maxDepth: null == maxDepth ? _self.maxDepth : maxDepth // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class FfiCommand_AccountPlaylists extends FfiCommand {
  const FfiCommand_AccountPlaylists({required this.source}): super._();
  

 final  String source;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_AccountPlaylistsCopyWith<FfiCommand_AccountPlaylists> get copyWith => _$FfiCommand_AccountPlaylistsCopyWithImpl<FfiCommand_AccountPlaylists>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_AccountPlaylists&&(identical(other.source, source) || other.source == source));
}


@override
int get hashCode => Object.hash(runtimeType,source);

@override
String toString() {
  return 'FfiCommand.accountPlaylists(source: $source)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_AccountPlaylistsCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_AccountPlaylistsCopyWith(FfiCommand_AccountPlaylists value, $Res Function(FfiCommand_AccountPlaylists) _then) = _$FfiCommand_AccountPlaylistsCopyWithImpl;
@useResult
$Res call({
 String source
});




}
/// @nodoc
class _$FfiCommand_AccountPlaylistsCopyWithImpl<$Res>
    implements $FfiCommand_AccountPlaylistsCopyWith<$Res> {
  _$FfiCommand_AccountPlaylistsCopyWithImpl(this._self, this._then);

  final FfiCommand_AccountPlaylists _self;
  final $Res Function(FfiCommand_AccountPlaylists) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? source = null,}) {
  return _then(FfiCommand_AccountPlaylists(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class FfiCommand_AccountFavorites extends FfiCommand {
  const FfiCommand_AccountFavorites({required this.source}): super._();
  

 final  String source;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_AccountFavoritesCopyWith<FfiCommand_AccountFavorites> get copyWith => _$FfiCommand_AccountFavoritesCopyWithImpl<FfiCommand_AccountFavorites>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_AccountFavorites&&(identical(other.source, source) || other.source == source));
}


@override
int get hashCode => Object.hash(runtimeType,source);

@override
String toString() {
  return 'FfiCommand.accountFavorites(source: $source)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_AccountFavoritesCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_AccountFavoritesCopyWith(FfiCommand_AccountFavorites value, $Res Function(FfiCommand_AccountFavorites) _then) = _$FfiCommand_AccountFavoritesCopyWithImpl;
@useResult
$Res call({
 String source
});




}
/// @nodoc
class _$FfiCommand_AccountFavoritesCopyWithImpl<$Res>
    implements $FfiCommand_AccountFavoritesCopyWith<$Res> {
  _$FfiCommand_AccountFavoritesCopyWithImpl(this._self, this._then);

  final FfiCommand_AccountFavorites _self;
  final $Res Function(FfiCommand_AccountFavorites) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? source = null,}) {
  return _then(FfiCommand_AccountFavorites(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class FfiCommand_AccountPlaylistDetail extends FfiCommand {
  const FfiCommand_AccountPlaylistDetail({required this.source, required this.playlistId}): super._();
  

 final  String source;
 final  String playlistId;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_AccountPlaylistDetailCopyWith<FfiCommand_AccountPlaylistDetail> get copyWith => _$FfiCommand_AccountPlaylistDetailCopyWithImpl<FfiCommand_AccountPlaylistDetail>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_AccountPlaylistDetail&&(identical(other.source, source) || other.source == source)&&(identical(other.playlistId, playlistId) || other.playlistId == playlistId));
}


@override
int get hashCode => Object.hash(runtimeType,source,playlistId);

@override
String toString() {
  return 'FfiCommand.accountPlaylistDetail(source: $source, playlistId: $playlistId)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_AccountPlaylistDetailCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_AccountPlaylistDetailCopyWith(FfiCommand_AccountPlaylistDetail value, $Res Function(FfiCommand_AccountPlaylistDetail) _then) = _$FfiCommand_AccountPlaylistDetailCopyWithImpl;
@useResult
$Res call({
 String source, String playlistId
});




}
/// @nodoc
class _$FfiCommand_AccountPlaylistDetailCopyWithImpl<$Res>
    implements $FfiCommand_AccountPlaylistDetailCopyWith<$Res> {
  _$FfiCommand_AccountPlaylistDetailCopyWithImpl(this._self, this._then);

  final FfiCommand_AccountPlaylistDetail _self;
  final $Res Function(FfiCommand_AccountPlaylistDetail) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? source = null,Object? playlistId = null,}) {
  return _then(FfiCommand_AccountPlaylistDetail(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,playlistId: null == playlistId ? _self.playlistId : playlistId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class FfiCommand_SyncPreview extends FfiCommand {
  const FfiCommand_SyncPreview({required this.source}): super._();
  

 final  String source;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_SyncPreviewCopyWith<FfiCommand_SyncPreview> get copyWith => _$FfiCommand_SyncPreviewCopyWithImpl<FfiCommand_SyncPreview>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_SyncPreview&&(identical(other.source, source) || other.source == source));
}


@override
int get hashCode => Object.hash(runtimeType,source);

@override
String toString() {
  return 'FfiCommand.syncPreview(source: $source)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_SyncPreviewCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_SyncPreviewCopyWith(FfiCommand_SyncPreview value, $Res Function(FfiCommand_SyncPreview) _then) = _$FfiCommand_SyncPreviewCopyWithImpl;
@useResult
$Res call({
 String source
});




}
/// @nodoc
class _$FfiCommand_SyncPreviewCopyWithImpl<$Res>
    implements $FfiCommand_SyncPreviewCopyWith<$Res> {
  _$FfiCommand_SyncPreviewCopyWithImpl(this._self, this._then);

  final FfiCommand_SyncPreview _self;
  final $Res Function(FfiCommand_SyncPreview) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? source = null,}) {
  return _then(FfiCommand_SyncPreview(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class FfiCommand_SyncRun extends FfiCommand {
  const FfiCommand_SyncRun({required this.source}): super._();
  

 final  String source;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_SyncRunCopyWith<FfiCommand_SyncRun> get copyWith => _$FfiCommand_SyncRunCopyWithImpl<FfiCommand_SyncRun>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_SyncRun&&(identical(other.source, source) || other.source == source));
}


@override
int get hashCode => Object.hash(runtimeType,source);

@override
String toString() {
  return 'FfiCommand.syncRun(source: $source)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_SyncRunCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_SyncRunCopyWith(FfiCommand_SyncRun value, $Res Function(FfiCommand_SyncRun) _then) = _$FfiCommand_SyncRunCopyWithImpl;
@useResult
$Res call({
 String source
});




}
/// @nodoc
class _$FfiCommand_SyncRunCopyWithImpl<$Res>
    implements $FfiCommand_SyncRunCopyWith<$Res> {
  _$FfiCommand_SyncRunCopyWithImpl(this._self, this._then);

  final FfiCommand_SyncRun _self;
  final $Res Function(FfiCommand_SyncRun) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? source = null,}) {
  return _then(FfiCommand_SyncRun(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class FfiCommand_SyncCancel extends FfiCommand {
  const FfiCommand_SyncCancel(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_SyncCancel);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FfiCommand.syncCancel()';
}


}




/// @nodoc


class FfiCommand_PushTargets extends FfiCommand {
  const FfiCommand_PushTargets({required this.source}): super._();
  

 final  String source;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_PushTargetsCopyWith<FfiCommand_PushTargets> get copyWith => _$FfiCommand_PushTargetsCopyWithImpl<FfiCommand_PushTargets>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_PushTargets&&(identical(other.source, source) || other.source == source));
}


@override
int get hashCode => Object.hash(runtimeType,source);

@override
String toString() {
  return 'FfiCommand.pushTargets(source: $source)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_PushTargetsCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_PushTargetsCopyWith(FfiCommand_PushTargets value, $Res Function(FfiCommand_PushTargets) _then) = _$FfiCommand_PushTargetsCopyWithImpl;
@useResult
$Res call({
 String source
});




}
/// @nodoc
class _$FfiCommand_PushTargetsCopyWithImpl<$Res>
    implements $FfiCommand_PushTargetsCopyWith<$Res> {
  _$FfiCommand_PushTargetsCopyWithImpl(this._self, this._then);

  final FfiCommand_PushTargets _self;
  final $Res Function(FfiCommand_PushTargets) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? source = null,}) {
  return _then(FfiCommand_PushTargets(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class FfiCommand_PushCreateTarget extends FfiCommand {
  const FfiCommand_PushCreateTarget({required this.source, required this.name}): super._();
  

 final  String source;
 final  String name;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_PushCreateTargetCopyWith<FfiCommand_PushCreateTarget> get copyWith => _$FfiCommand_PushCreateTargetCopyWithImpl<FfiCommand_PushCreateTarget>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_PushCreateTarget&&(identical(other.source, source) || other.source == source)&&(identical(other.name, name) || other.name == name));
}


@override
int get hashCode => Object.hash(runtimeType,source,name);

@override
String toString() {
  return 'FfiCommand.pushCreateTarget(source: $source, name: $name)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_PushCreateTargetCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_PushCreateTargetCopyWith(FfiCommand_PushCreateTarget value, $Res Function(FfiCommand_PushCreateTarget) _then) = _$FfiCommand_PushCreateTargetCopyWithImpl;
@useResult
$Res call({
 String source, String name
});




}
/// @nodoc
class _$FfiCommand_PushCreateTargetCopyWithImpl<$Res>
    implements $FfiCommand_PushCreateTargetCopyWith<$Res> {
  _$FfiCommand_PushCreateTargetCopyWithImpl(this._self, this._then);

  final FfiCommand_PushCreateTarget _self;
  final $Res Function(FfiCommand_PushCreateTarget) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? source = null,Object? name = null,}) {
  return _then(FfiCommand_PushCreateTarget(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class FfiCommand_PushPlan extends FfiCommand {
  const FfiCommand_PushPlan({required this.source, required this.localName, required final  List<SongDto> localSongs, required this.isFavorites, required this.targetKind, required this.targetId, required this.targetName, required this.targetSongCount}): _localSongs = localSongs,super._();
  

 final  String source;
 final  String localName;
 final  List<SongDto> _localSongs;
 List<SongDto> get localSongs {
  if (_localSongs is EqualUnmodifiableListView) return _localSongs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_localSongs);
}

 final  bool isFavorites;
 final  String targetKind;
 final  String targetId;
 final  String targetName;
 final  int targetSongCount;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_PushPlanCopyWith<FfiCommand_PushPlan> get copyWith => _$FfiCommand_PushPlanCopyWithImpl<FfiCommand_PushPlan>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_PushPlan&&(identical(other.source, source) || other.source == source)&&(identical(other.localName, localName) || other.localName == localName)&&const DeepCollectionEquality().equals(other._localSongs, _localSongs)&&(identical(other.isFavorites, isFavorites) || other.isFavorites == isFavorites)&&(identical(other.targetKind, targetKind) || other.targetKind == targetKind)&&(identical(other.targetId, targetId) || other.targetId == targetId)&&(identical(other.targetName, targetName) || other.targetName == targetName)&&(identical(other.targetSongCount, targetSongCount) || other.targetSongCount == targetSongCount));
}


@override
int get hashCode => Object.hash(runtimeType,source,localName,const DeepCollectionEquality().hash(_localSongs),isFavorites,targetKind,targetId,targetName,targetSongCount);

@override
String toString() {
  return 'FfiCommand.pushPlan(source: $source, localName: $localName, localSongs: $localSongs, isFavorites: $isFavorites, targetKind: $targetKind, targetId: $targetId, targetName: $targetName, targetSongCount: $targetSongCount)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_PushPlanCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_PushPlanCopyWith(FfiCommand_PushPlan value, $Res Function(FfiCommand_PushPlan) _then) = _$FfiCommand_PushPlanCopyWithImpl;
@useResult
$Res call({
 String source, String localName, List<SongDto> localSongs, bool isFavorites, String targetKind, String targetId, String targetName, int targetSongCount
});




}
/// @nodoc
class _$FfiCommand_PushPlanCopyWithImpl<$Res>
    implements $FfiCommand_PushPlanCopyWith<$Res> {
  _$FfiCommand_PushPlanCopyWithImpl(this._self, this._then);

  final FfiCommand_PushPlan _self;
  final $Res Function(FfiCommand_PushPlan) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? source = null,Object? localName = null,Object? localSongs = null,Object? isFavorites = null,Object? targetKind = null,Object? targetId = null,Object? targetName = null,Object? targetSongCount = null,}) {
  return _then(FfiCommand_PushPlan(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,localName: null == localName ? _self.localName : localName // ignore: cast_nullable_to_non_nullable
as String,localSongs: null == localSongs ? _self._localSongs : localSongs // ignore: cast_nullable_to_non_nullable
as List<SongDto>,isFavorites: null == isFavorites ? _self.isFavorites : isFavorites // ignore: cast_nullable_to_non_nullable
as bool,targetKind: null == targetKind ? _self.targetKind : targetKind // ignore: cast_nullable_to_non_nullable
as String,targetId: null == targetId ? _self.targetId : targetId // ignore: cast_nullable_to_non_nullable
as String,targetName: null == targetName ? _self.targetName : targetName // ignore: cast_nullable_to_non_nullable
as String,targetSongCount: null == targetSongCount ? _self.targetSongCount : targetSongCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class FfiCommand_PushRun extends FfiCommand {
  const FfiCommand_PushRun({required this.source}): super._();
  

 final  String source;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_PushRunCopyWith<FfiCommand_PushRun> get copyWith => _$FfiCommand_PushRunCopyWithImpl<FfiCommand_PushRun>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_PushRun&&(identical(other.source, source) || other.source == source));
}


@override
int get hashCode => Object.hash(runtimeType,source);

@override
String toString() {
  return 'FfiCommand.pushRun(source: $source)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_PushRunCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_PushRunCopyWith(FfiCommand_PushRun value, $Res Function(FfiCommand_PushRun) _then) = _$FfiCommand_PushRunCopyWithImpl;
@useResult
$Res call({
 String source
});




}
/// @nodoc
class _$FfiCommand_PushRunCopyWithImpl<$Res>
    implements $FfiCommand_PushRunCopyWith<$Res> {
  _$FfiCommand_PushRunCopyWithImpl(this._self, this._then);

  final FfiCommand_PushRun _self;
  final $Res Function(FfiCommand_PushRun) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? source = null,}) {
  return _then(FfiCommand_PushRun(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class FfiCommand_PushCancel extends FfiCommand {
  const FfiCommand_PushCancel(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_PushCancel);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FfiCommand.pushCancel()';
}


}




/// @nodoc


class FfiCommand_PlaylistCategories extends FfiCommand {
  const FfiCommand_PlaylistCategories({required this.source}): super._();
  

 final  String source;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_PlaylistCategoriesCopyWith<FfiCommand_PlaylistCategories> get copyWith => _$FfiCommand_PlaylistCategoriesCopyWithImpl<FfiCommand_PlaylistCategories>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_PlaylistCategories&&(identical(other.source, source) || other.source == source));
}


@override
int get hashCode => Object.hash(runtimeType,source);

@override
String toString() {
  return 'FfiCommand.playlistCategories(source: $source)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_PlaylistCategoriesCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_PlaylistCategoriesCopyWith(FfiCommand_PlaylistCategories value, $Res Function(FfiCommand_PlaylistCategories) _then) = _$FfiCommand_PlaylistCategoriesCopyWithImpl;
@useResult
$Res call({
 String source
});




}
/// @nodoc
class _$FfiCommand_PlaylistCategoriesCopyWithImpl<$Res>
    implements $FfiCommand_PlaylistCategoriesCopyWith<$Res> {
  _$FfiCommand_PlaylistCategoriesCopyWithImpl(this._self, this._then);

  final FfiCommand_PlaylistCategories _self;
  final $Res Function(FfiCommand_PlaylistCategories) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? source = null,}) {
  return _then(FfiCommand_PlaylistCategories(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class FfiCommand_PlaylistList extends FfiCommand {
  const FfiCommand_PlaylistList({required this.source, required this.category, required this.page}): super._();
  

 final  String source;
 final  String category;
 final  int page;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_PlaylistListCopyWith<FfiCommand_PlaylistList> get copyWith => _$FfiCommand_PlaylistListCopyWithImpl<FfiCommand_PlaylistList>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_PlaylistList&&(identical(other.source, source) || other.source == source)&&(identical(other.category, category) || other.category == category)&&(identical(other.page, page) || other.page == page));
}


@override
int get hashCode => Object.hash(runtimeType,source,category,page);

@override
String toString() {
  return 'FfiCommand.playlistList(source: $source, category: $category, page: $page)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_PlaylistListCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_PlaylistListCopyWith(FfiCommand_PlaylistList value, $Res Function(FfiCommand_PlaylistList) _then) = _$FfiCommand_PlaylistListCopyWithImpl;
@useResult
$Res call({
 String source, String category, int page
});




}
/// @nodoc
class _$FfiCommand_PlaylistListCopyWithImpl<$Res>
    implements $FfiCommand_PlaylistListCopyWith<$Res> {
  _$FfiCommand_PlaylistListCopyWithImpl(this._self, this._then);

  final FfiCommand_PlaylistList _self;
  final $Res Function(FfiCommand_PlaylistList) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? source = null,Object? category = null,Object? page = null,}) {
  return _then(FfiCommand_PlaylistList(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class FfiCommand_PlaylistDetail extends FfiCommand {
  const FfiCommand_PlaylistDetail({required this.source, required this.playlistId, required this.page}): super._();
  

 final  String source;
 final  String playlistId;
 final  int page;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_PlaylistDetailCopyWith<FfiCommand_PlaylistDetail> get copyWith => _$FfiCommand_PlaylistDetailCopyWithImpl<FfiCommand_PlaylistDetail>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_PlaylistDetail&&(identical(other.source, source) || other.source == source)&&(identical(other.playlistId, playlistId) || other.playlistId == playlistId)&&(identical(other.page, page) || other.page == page));
}


@override
int get hashCode => Object.hash(runtimeType,source,playlistId,page);

@override
String toString() {
  return 'FfiCommand.playlistDetail(source: $source, playlistId: $playlistId, page: $page)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_PlaylistDetailCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_PlaylistDetailCopyWith(FfiCommand_PlaylistDetail value, $Res Function(FfiCommand_PlaylistDetail) _then) = _$FfiCommand_PlaylistDetailCopyWithImpl;
@useResult
$Res call({
 String source, String playlistId, int page
});




}
/// @nodoc
class _$FfiCommand_PlaylistDetailCopyWithImpl<$Res>
    implements $FfiCommand_PlaylistDetailCopyWith<$Res> {
  _$FfiCommand_PlaylistDetailCopyWithImpl(this._self, this._then);

  final FfiCommand_PlaylistDetail _self;
  final $Res Function(FfiCommand_PlaylistDetail) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? source = null,Object? playlistId = null,Object? page = null,}) {
  return _then(FfiCommand_PlaylistDetail(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,playlistId: null == playlistId ? _self.playlistId : playlistId // ignore: cast_nullable_to_non_nullable
as String,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class FfiCommand_LeaderboardBoards extends FfiCommand {
  const FfiCommand_LeaderboardBoards({required this.source}): super._();
  

 final  String source;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_LeaderboardBoardsCopyWith<FfiCommand_LeaderboardBoards> get copyWith => _$FfiCommand_LeaderboardBoardsCopyWithImpl<FfiCommand_LeaderboardBoards>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_LeaderboardBoards&&(identical(other.source, source) || other.source == source));
}


@override
int get hashCode => Object.hash(runtimeType,source);

@override
String toString() {
  return 'FfiCommand.leaderboardBoards(source: $source)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_LeaderboardBoardsCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_LeaderboardBoardsCopyWith(FfiCommand_LeaderboardBoards value, $Res Function(FfiCommand_LeaderboardBoards) _then) = _$FfiCommand_LeaderboardBoardsCopyWithImpl;
@useResult
$Res call({
 String source
});




}
/// @nodoc
class _$FfiCommand_LeaderboardBoardsCopyWithImpl<$Res>
    implements $FfiCommand_LeaderboardBoardsCopyWith<$Res> {
  _$FfiCommand_LeaderboardBoardsCopyWithImpl(this._self, this._then);

  final FfiCommand_LeaderboardBoards _self;
  final $Res Function(FfiCommand_LeaderboardBoards) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? source = null,}) {
  return _then(FfiCommand_LeaderboardBoards(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class FfiCommand_LeaderboardSongs extends FfiCommand {
  const FfiCommand_LeaderboardSongs({required this.source, required this.boardId, required this.page}): super._();
  

 final  String source;
 final  String boardId;
 final  int page;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_LeaderboardSongsCopyWith<FfiCommand_LeaderboardSongs> get copyWith => _$FfiCommand_LeaderboardSongsCopyWithImpl<FfiCommand_LeaderboardSongs>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_LeaderboardSongs&&(identical(other.source, source) || other.source == source)&&(identical(other.boardId, boardId) || other.boardId == boardId)&&(identical(other.page, page) || other.page == page));
}


@override
int get hashCode => Object.hash(runtimeType,source,boardId,page);

@override
String toString() {
  return 'FfiCommand.leaderboardSongs(source: $source, boardId: $boardId, page: $page)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_LeaderboardSongsCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_LeaderboardSongsCopyWith(FfiCommand_LeaderboardSongs value, $Res Function(FfiCommand_LeaderboardSongs) _then) = _$FfiCommand_LeaderboardSongsCopyWithImpl;
@useResult
$Res call({
 String source, String boardId, int page
});




}
/// @nodoc
class _$FfiCommand_LeaderboardSongsCopyWithImpl<$Res>
    implements $FfiCommand_LeaderboardSongsCopyWith<$Res> {
  _$FfiCommand_LeaderboardSongsCopyWithImpl(this._self, this._then);

  final FfiCommand_LeaderboardSongs _self;
  final $Res Function(FfiCommand_LeaderboardSongs) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? source = null,Object? boardId = null,Object? page = null,}) {
  return _then(FfiCommand_LeaderboardSongs(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,boardId: null == boardId ? _self.boardId : boardId // ignore: cast_nullable_to_non_nullable
as String,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class FfiCommand_ArtistSongs extends FfiCommand {
  const FfiCommand_ArtistSongs({required this.artist, required this.page}): super._();
  

 final  ArtistDto artist;
 final  int page;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_ArtistSongsCopyWith<FfiCommand_ArtistSongs> get copyWith => _$FfiCommand_ArtistSongsCopyWithImpl<FfiCommand_ArtistSongs>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_ArtistSongs&&(identical(other.artist, artist) || other.artist == artist)&&(identical(other.page, page) || other.page == page));
}


@override
int get hashCode => Object.hash(runtimeType,artist,page);

@override
String toString() {
  return 'FfiCommand.artistSongs(artist: $artist, page: $page)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_ArtistSongsCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_ArtistSongsCopyWith(FfiCommand_ArtistSongs value, $Res Function(FfiCommand_ArtistSongs) _then) = _$FfiCommand_ArtistSongsCopyWithImpl;
@useResult
$Res call({
 ArtistDto artist, int page
});




}
/// @nodoc
class _$FfiCommand_ArtistSongsCopyWithImpl<$Res>
    implements $FfiCommand_ArtistSongsCopyWith<$Res> {
  _$FfiCommand_ArtistSongsCopyWithImpl(this._self, this._then);

  final FfiCommand_ArtistSongs _self;
  final $Res Function(FfiCommand_ArtistSongs) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? artist = null,Object? page = null,}) {
  return _then(FfiCommand_ArtistSongs(
artist: null == artist ? _self.artist : artist // ignore: cast_nullable_to_non_nullable
as ArtistDto,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class FfiCommand_ArtistAlbums extends FfiCommand {
  const FfiCommand_ArtistAlbums({required this.artist, required this.page}): super._();
  

 final  ArtistDto artist;
 final  int page;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_ArtistAlbumsCopyWith<FfiCommand_ArtistAlbums> get copyWith => _$FfiCommand_ArtistAlbumsCopyWithImpl<FfiCommand_ArtistAlbums>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_ArtistAlbums&&(identical(other.artist, artist) || other.artist == artist)&&(identical(other.page, page) || other.page == page));
}


@override
int get hashCode => Object.hash(runtimeType,artist,page);

@override
String toString() {
  return 'FfiCommand.artistAlbums(artist: $artist, page: $page)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_ArtistAlbumsCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_ArtistAlbumsCopyWith(FfiCommand_ArtistAlbums value, $Res Function(FfiCommand_ArtistAlbums) _then) = _$FfiCommand_ArtistAlbumsCopyWithImpl;
@useResult
$Res call({
 ArtistDto artist, int page
});




}
/// @nodoc
class _$FfiCommand_ArtistAlbumsCopyWithImpl<$Res>
    implements $FfiCommand_ArtistAlbumsCopyWith<$Res> {
  _$FfiCommand_ArtistAlbumsCopyWithImpl(this._self, this._then);

  final FfiCommand_ArtistAlbums _self;
  final $Res Function(FfiCommand_ArtistAlbums) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? artist = null,Object? page = null,}) {
  return _then(FfiCommand_ArtistAlbums(
artist: null == artist ? _self.artist : artist // ignore: cast_nullable_to_non_nullable
as ArtistDto,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class FfiCommand_AlbumSongs extends FfiCommand {
  const FfiCommand_AlbumSongs({required this.album, required this.page}): super._();
  

 final  AlbumDto album;
 final  int page;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_AlbumSongsCopyWith<FfiCommand_AlbumSongs> get copyWith => _$FfiCommand_AlbumSongsCopyWithImpl<FfiCommand_AlbumSongs>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_AlbumSongs&&(identical(other.album, album) || other.album == album)&&(identical(other.page, page) || other.page == page));
}


@override
int get hashCode => Object.hash(runtimeType,album,page);

@override
String toString() {
  return 'FfiCommand.albumSongs(album: $album, page: $page)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_AlbumSongsCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_AlbumSongsCopyWith(FfiCommand_AlbumSongs value, $Res Function(FfiCommand_AlbumSongs) _then) = _$FfiCommand_AlbumSongsCopyWithImpl;
@useResult
$Res call({
 AlbumDto album, int page
});




}
/// @nodoc
class _$FfiCommand_AlbumSongsCopyWithImpl<$Res>
    implements $FfiCommand_AlbumSongsCopyWith<$Res> {
  _$FfiCommand_AlbumSongsCopyWithImpl(this._self, this._then);

  final FfiCommand_AlbumSongs _self;
  final $Res Function(FfiCommand_AlbumSongs) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? album = null,Object? page = null,}) {
  return _then(FfiCommand_AlbumSongs(
album: null == album ? _self.album : album // ignore: cast_nullable_to_non_nullable
as AlbumDto,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class FfiCommand_PlaySongs extends FfiCommand {
  const FfiCommand_PlaySongs({required final  List<SongDto> songs, required this.index}): _songs = songs,super._();
  

 final  List<SongDto> _songs;
 List<SongDto> get songs {
  if (_songs is EqualUnmodifiableListView) return _songs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_songs);
}

 final  int index;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FfiCommand_PlaySongsCopyWith<FfiCommand_PlaySongs> get copyWith => _$FfiCommand_PlaySongsCopyWithImpl<FfiCommand_PlaySongs>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FfiCommand_PlaySongs&&const DeepCollectionEquality().equals(other._songs, _songs)&&(identical(other.index, index) || other.index == index));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_songs),index);

@override
String toString() {
  return 'FfiCommand.playSongs(songs: $songs, index: $index)';
}


}

/// @nodoc
abstract mixin class $FfiCommand_PlaySongsCopyWith<$Res> implements $FfiCommandCopyWith<$Res> {
  factory $FfiCommand_PlaySongsCopyWith(FfiCommand_PlaySongs value, $Res Function(FfiCommand_PlaySongs) _then) = _$FfiCommand_PlaySongsCopyWithImpl;
@useResult
$Res call({
 List<SongDto> songs, int index
});




}
/// @nodoc
class _$FfiCommand_PlaySongsCopyWithImpl<$Res>
    implements $FfiCommand_PlaySongsCopyWith<$Res> {
  _$FfiCommand_PlaySongsCopyWithImpl(this._self, this._then);

  final FfiCommand_PlaySongs _self;
  final $Res Function(FfiCommand_PlaySongs) _then;

/// Create a copy of FfiCommand
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? songs = null,Object? index = null,}) {
  return _then(FfiCommand_PlaySongs(
songs: null == songs ? _self._songs : songs // ignore: cast_nullable_to_non_nullable
as List<SongDto>,index: null == index ? _self.index : index // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$HostPlayerCommandDto {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HostPlayerCommandDto);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'HostPlayerCommandDto()';
}


}

/// @nodoc
class $HostPlayerCommandDtoCopyWith<$Res>  {
$HostPlayerCommandDtoCopyWith(HostPlayerCommandDto _, $Res Function(HostPlayerCommandDto) __);
}


/// Adds pattern-matching-related methods to [HostPlayerCommandDto].
extension HostPlayerCommandDtoPatterns on HostPlayerCommandDto {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( HostPlayerCommandDto_Play value)?  play,TResult Function( HostPlayerCommandDto_Pause value)?  pause,TResult Function( HostPlayerCommandDto_Resume value)?  resume,TResult Function( HostPlayerCommandDto_Stop value)?  stop,TResult Function( HostPlayerCommandDto_Toggle value)?  toggle,TResult Function( HostPlayerCommandDto_Seek value)?  seek,TResult Function( HostPlayerCommandDto_SetVolume value)?  setVolume,TResult Function( HostPlayerCommandDto_SetSpeed value)?  setSpeed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case HostPlayerCommandDto_Play() when play != null:
return play(_that);case HostPlayerCommandDto_Pause() when pause != null:
return pause(_that);case HostPlayerCommandDto_Resume() when resume != null:
return resume(_that);case HostPlayerCommandDto_Stop() when stop != null:
return stop(_that);case HostPlayerCommandDto_Toggle() when toggle != null:
return toggle(_that);case HostPlayerCommandDto_Seek() when seek != null:
return seek(_that);case HostPlayerCommandDto_SetVolume() when setVolume != null:
return setVolume(_that);case HostPlayerCommandDto_SetSpeed() when setSpeed != null:
return setSpeed(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( HostPlayerCommandDto_Play value)  play,required TResult Function( HostPlayerCommandDto_Pause value)  pause,required TResult Function( HostPlayerCommandDto_Resume value)  resume,required TResult Function( HostPlayerCommandDto_Stop value)  stop,required TResult Function( HostPlayerCommandDto_Toggle value)  toggle,required TResult Function( HostPlayerCommandDto_Seek value)  seek,required TResult Function( HostPlayerCommandDto_SetVolume value)  setVolume,required TResult Function( HostPlayerCommandDto_SetSpeed value)  setSpeed,}){
final _that = this;
switch (_that) {
case HostPlayerCommandDto_Play():
return play(_that);case HostPlayerCommandDto_Pause():
return pause(_that);case HostPlayerCommandDto_Resume():
return resume(_that);case HostPlayerCommandDto_Stop():
return stop(_that);case HostPlayerCommandDto_Toggle():
return toggle(_that);case HostPlayerCommandDto_Seek():
return seek(_that);case HostPlayerCommandDto_SetVolume():
return setVolume(_that);case HostPlayerCommandDto_SetSpeed():
return setSpeed(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( HostPlayerCommandDto_Play value)?  play,TResult? Function( HostPlayerCommandDto_Pause value)?  pause,TResult? Function( HostPlayerCommandDto_Resume value)?  resume,TResult? Function( HostPlayerCommandDto_Stop value)?  stop,TResult? Function( HostPlayerCommandDto_Toggle value)?  toggle,TResult? Function( HostPlayerCommandDto_Seek value)?  seek,TResult? Function( HostPlayerCommandDto_SetVolume value)?  setVolume,TResult? Function( HostPlayerCommandDto_SetSpeed value)?  setSpeed,}){
final _that = this;
switch (_that) {
case HostPlayerCommandDto_Play() when play != null:
return play(_that);case HostPlayerCommandDto_Pause() when pause != null:
return pause(_that);case HostPlayerCommandDto_Resume() when resume != null:
return resume(_that);case HostPlayerCommandDto_Stop() when stop != null:
return stop(_that);case HostPlayerCommandDto_Toggle() when toggle != null:
return toggle(_that);case HostPlayerCommandDto_Seek() when seek != null:
return seek(_that);case HostPlayerCommandDto_SetVolume() when setVolume != null:
return setVolume(_that);case HostPlayerCommandDto_SetSpeed() when setSpeed != null:
return setSpeed(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String url,  BigInt generation,  List<HostHeaderDto> headers)?  play,TResult Function()?  pause,TResult Function()?  resume,TResult Function()?  stop,TResult Function()?  toggle,TResult Function( BigInt positionMs)?  seek,TResult Function( int volume)?  setVolume,TResult Function( double speed)?  setSpeed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case HostPlayerCommandDto_Play() when play != null:
return play(_that.url,_that.generation,_that.headers);case HostPlayerCommandDto_Pause() when pause != null:
return pause();case HostPlayerCommandDto_Resume() when resume != null:
return resume();case HostPlayerCommandDto_Stop() when stop != null:
return stop();case HostPlayerCommandDto_Toggle() when toggle != null:
return toggle();case HostPlayerCommandDto_Seek() when seek != null:
return seek(_that.positionMs);case HostPlayerCommandDto_SetVolume() when setVolume != null:
return setVolume(_that.volume);case HostPlayerCommandDto_SetSpeed() when setSpeed != null:
return setSpeed(_that.speed);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String url,  BigInt generation,  List<HostHeaderDto> headers)  play,required TResult Function()  pause,required TResult Function()  resume,required TResult Function()  stop,required TResult Function()  toggle,required TResult Function( BigInt positionMs)  seek,required TResult Function( int volume)  setVolume,required TResult Function( double speed)  setSpeed,}) {final _that = this;
switch (_that) {
case HostPlayerCommandDto_Play():
return play(_that.url,_that.generation,_that.headers);case HostPlayerCommandDto_Pause():
return pause();case HostPlayerCommandDto_Resume():
return resume();case HostPlayerCommandDto_Stop():
return stop();case HostPlayerCommandDto_Toggle():
return toggle();case HostPlayerCommandDto_Seek():
return seek(_that.positionMs);case HostPlayerCommandDto_SetVolume():
return setVolume(_that.volume);case HostPlayerCommandDto_SetSpeed():
return setSpeed(_that.speed);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String url,  BigInt generation,  List<HostHeaderDto> headers)?  play,TResult? Function()?  pause,TResult? Function()?  resume,TResult? Function()?  stop,TResult? Function()?  toggle,TResult? Function( BigInt positionMs)?  seek,TResult? Function( int volume)?  setVolume,TResult? Function( double speed)?  setSpeed,}) {final _that = this;
switch (_that) {
case HostPlayerCommandDto_Play() when play != null:
return play(_that.url,_that.generation,_that.headers);case HostPlayerCommandDto_Pause() when pause != null:
return pause();case HostPlayerCommandDto_Resume() when resume != null:
return resume();case HostPlayerCommandDto_Stop() when stop != null:
return stop();case HostPlayerCommandDto_Toggle() when toggle != null:
return toggle();case HostPlayerCommandDto_Seek() when seek != null:
return seek(_that.positionMs);case HostPlayerCommandDto_SetVolume() when setVolume != null:
return setVolume(_that.volume);case HostPlayerCommandDto_SetSpeed() when setSpeed != null:
return setSpeed(_that.speed);case _:
  return null;

}
}

}

/// @nodoc


class HostPlayerCommandDto_Play extends HostPlayerCommandDto {
  const HostPlayerCommandDto_Play({required this.url, required this.generation, required final  List<HostHeaderDto> headers}): _headers = headers,super._();
  

 final  String url;
 final  BigInt generation;
 final  List<HostHeaderDto> _headers;
 List<HostHeaderDto> get headers {
  if (_headers is EqualUnmodifiableListView) return _headers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_headers);
}


/// Create a copy of HostPlayerCommandDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HostPlayerCommandDto_PlayCopyWith<HostPlayerCommandDto_Play> get copyWith => _$HostPlayerCommandDto_PlayCopyWithImpl<HostPlayerCommandDto_Play>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HostPlayerCommandDto_Play&&(identical(other.url, url) || other.url == url)&&(identical(other.generation, generation) || other.generation == generation)&&const DeepCollectionEquality().equals(other._headers, _headers));
}


@override
int get hashCode => Object.hash(runtimeType,url,generation,const DeepCollectionEquality().hash(_headers));

@override
String toString() {
  return 'HostPlayerCommandDto.play(url: $url, generation: $generation, headers: $headers)';
}


}

/// @nodoc
abstract mixin class $HostPlayerCommandDto_PlayCopyWith<$Res> implements $HostPlayerCommandDtoCopyWith<$Res> {
  factory $HostPlayerCommandDto_PlayCopyWith(HostPlayerCommandDto_Play value, $Res Function(HostPlayerCommandDto_Play) _then) = _$HostPlayerCommandDto_PlayCopyWithImpl;
@useResult
$Res call({
 String url, BigInt generation, List<HostHeaderDto> headers
});




}
/// @nodoc
class _$HostPlayerCommandDto_PlayCopyWithImpl<$Res>
    implements $HostPlayerCommandDto_PlayCopyWith<$Res> {
  _$HostPlayerCommandDto_PlayCopyWithImpl(this._self, this._then);

  final HostPlayerCommandDto_Play _self;
  final $Res Function(HostPlayerCommandDto_Play) _then;

/// Create a copy of HostPlayerCommandDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? url = null,Object? generation = null,Object? headers = null,}) {
  return _then(HostPlayerCommandDto_Play(
url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,generation: null == generation ? _self.generation : generation // ignore: cast_nullable_to_non_nullable
as BigInt,headers: null == headers ? _self._headers : headers // ignore: cast_nullable_to_non_nullable
as List<HostHeaderDto>,
  ));
}


}

/// @nodoc


class HostPlayerCommandDto_Pause extends HostPlayerCommandDto {
  const HostPlayerCommandDto_Pause(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HostPlayerCommandDto_Pause);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'HostPlayerCommandDto.pause()';
}


}




/// @nodoc


class HostPlayerCommandDto_Resume extends HostPlayerCommandDto {
  const HostPlayerCommandDto_Resume(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HostPlayerCommandDto_Resume);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'HostPlayerCommandDto.resume()';
}


}




/// @nodoc


class HostPlayerCommandDto_Stop extends HostPlayerCommandDto {
  const HostPlayerCommandDto_Stop(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HostPlayerCommandDto_Stop);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'HostPlayerCommandDto.stop()';
}


}




/// @nodoc


class HostPlayerCommandDto_Toggle extends HostPlayerCommandDto {
  const HostPlayerCommandDto_Toggle(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HostPlayerCommandDto_Toggle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'HostPlayerCommandDto.toggle()';
}


}




/// @nodoc


class HostPlayerCommandDto_Seek extends HostPlayerCommandDto {
  const HostPlayerCommandDto_Seek({required this.positionMs}): super._();
  

 final  BigInt positionMs;

/// Create a copy of HostPlayerCommandDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HostPlayerCommandDto_SeekCopyWith<HostPlayerCommandDto_Seek> get copyWith => _$HostPlayerCommandDto_SeekCopyWithImpl<HostPlayerCommandDto_Seek>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HostPlayerCommandDto_Seek&&(identical(other.positionMs, positionMs) || other.positionMs == positionMs));
}


@override
int get hashCode => Object.hash(runtimeType,positionMs);

@override
String toString() {
  return 'HostPlayerCommandDto.seek(positionMs: $positionMs)';
}


}

/// @nodoc
abstract mixin class $HostPlayerCommandDto_SeekCopyWith<$Res> implements $HostPlayerCommandDtoCopyWith<$Res> {
  factory $HostPlayerCommandDto_SeekCopyWith(HostPlayerCommandDto_Seek value, $Res Function(HostPlayerCommandDto_Seek) _then) = _$HostPlayerCommandDto_SeekCopyWithImpl;
@useResult
$Res call({
 BigInt positionMs
});




}
/// @nodoc
class _$HostPlayerCommandDto_SeekCopyWithImpl<$Res>
    implements $HostPlayerCommandDto_SeekCopyWith<$Res> {
  _$HostPlayerCommandDto_SeekCopyWithImpl(this._self, this._then);

  final HostPlayerCommandDto_Seek _self;
  final $Res Function(HostPlayerCommandDto_Seek) _then;

/// Create a copy of HostPlayerCommandDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? positionMs = null,}) {
  return _then(HostPlayerCommandDto_Seek(
positionMs: null == positionMs ? _self.positionMs : positionMs // ignore: cast_nullable_to_non_nullable
as BigInt,
  ));
}


}

/// @nodoc


class HostPlayerCommandDto_SetVolume extends HostPlayerCommandDto {
  const HostPlayerCommandDto_SetVolume({required this.volume}): super._();
  

 final  int volume;

/// Create a copy of HostPlayerCommandDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HostPlayerCommandDto_SetVolumeCopyWith<HostPlayerCommandDto_SetVolume> get copyWith => _$HostPlayerCommandDto_SetVolumeCopyWithImpl<HostPlayerCommandDto_SetVolume>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HostPlayerCommandDto_SetVolume&&(identical(other.volume, volume) || other.volume == volume));
}


@override
int get hashCode => Object.hash(runtimeType,volume);

@override
String toString() {
  return 'HostPlayerCommandDto.setVolume(volume: $volume)';
}


}

/// @nodoc
abstract mixin class $HostPlayerCommandDto_SetVolumeCopyWith<$Res> implements $HostPlayerCommandDtoCopyWith<$Res> {
  factory $HostPlayerCommandDto_SetVolumeCopyWith(HostPlayerCommandDto_SetVolume value, $Res Function(HostPlayerCommandDto_SetVolume) _then) = _$HostPlayerCommandDto_SetVolumeCopyWithImpl;
@useResult
$Res call({
 int volume
});




}
/// @nodoc
class _$HostPlayerCommandDto_SetVolumeCopyWithImpl<$Res>
    implements $HostPlayerCommandDto_SetVolumeCopyWith<$Res> {
  _$HostPlayerCommandDto_SetVolumeCopyWithImpl(this._self, this._then);

  final HostPlayerCommandDto_SetVolume _self;
  final $Res Function(HostPlayerCommandDto_SetVolume) _then;

/// Create a copy of HostPlayerCommandDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? volume = null,}) {
  return _then(HostPlayerCommandDto_SetVolume(
volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class HostPlayerCommandDto_SetSpeed extends HostPlayerCommandDto {
  const HostPlayerCommandDto_SetSpeed({required this.speed}): super._();
  

 final  double speed;

/// Create a copy of HostPlayerCommandDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HostPlayerCommandDto_SetSpeedCopyWith<HostPlayerCommandDto_SetSpeed> get copyWith => _$HostPlayerCommandDto_SetSpeedCopyWithImpl<HostPlayerCommandDto_SetSpeed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HostPlayerCommandDto_SetSpeed&&(identical(other.speed, speed) || other.speed == speed));
}


@override
int get hashCode => Object.hash(runtimeType,speed);

@override
String toString() {
  return 'HostPlayerCommandDto.setSpeed(speed: $speed)';
}


}

/// @nodoc
abstract mixin class $HostPlayerCommandDto_SetSpeedCopyWith<$Res> implements $HostPlayerCommandDtoCopyWith<$Res> {
  factory $HostPlayerCommandDto_SetSpeedCopyWith(HostPlayerCommandDto_SetSpeed value, $Res Function(HostPlayerCommandDto_SetSpeed) _then) = _$HostPlayerCommandDto_SetSpeedCopyWithImpl;
@useResult
$Res call({
 double speed
});




}
/// @nodoc
class _$HostPlayerCommandDto_SetSpeedCopyWithImpl<$Res>
    implements $HostPlayerCommandDto_SetSpeedCopyWith<$Res> {
  _$HostPlayerCommandDto_SetSpeedCopyWithImpl(this._self, this._then);

  final HostPlayerCommandDto_SetSpeed _self;
  final $Res Function(HostPlayerCommandDto_SetSpeed) _then;

/// Create a copy of HostPlayerCommandDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? speed = null,}) {
  return _then(HostPlayerCommandDto_SetSpeed(
speed: null == speed ? _self.speed : speed // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
