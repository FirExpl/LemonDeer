//
//  VideoDownloader.swift
//  WindmillComic
//
//  Created by Ziyi Zhang on 09/06/2017.
//  Copyright © 2017 Ziyideas. All rights reserved.
//

import Foundation

protocol VideoDownloaderDelegate {
  func videoDownloadSucceeded(by downloader: VideoDownloader)
  func videoDownloadFailed(by downloader: VideoDownloader)
  
  func updateProgressLabel(by percentage: String)
}

open class VideoDownloader {
  var m3u8Data: String = ""
  var tsPlaylist = M3u8Playlist()
  var segmentDownloaders = [SegmentDownloader]()
  var tsFilesIndex = 0
  var downloadedTsFilesCount = 0
  var neededDownloadTsFilesCount = 0
  var downloadURLs = [String]()
  var downloadingProgress: String {
    let fraction: Float = Float((Float(downloadedTsFilesCount) / Float(neededDownloadTsFilesCount)) * 100)
    let roundedValue: Int = Int(fraction.rounded(.toNearestOrEven))
    let progressString = roundedValue.description + " %"
    
    return progressString
  }
  
  var delegate: VideoDownloaderDelegate?
  
  open func startDownload() {
    checkOrCreatedM3u8Directory()
    
    var newSegmentArray = [M3u8TsSegmentModel]()
    
    let notInDownloadList = tsPlaylist.tsSegmentArray.filter { !downloadURLs.contains($0.locationURL) }
    neededDownloadTsFilesCount = notInDownloadList.count
    
    for i in 0 ..< notInDownloadList.count {
      let fileName = "\(tsFilesIndex).ts"
      
      let segmentDownloader = SegmentDownloader(with: notInDownloadList[i].locationURL,
                                                filePath: tsPlaylist.identifier,
                                                fileName: fileName,
                                                duration: notInDownloadList[i].duration,
                                                index: tsFilesIndex)
      segmentDownloader.delegate = self
      
      segmentDownloaders.append(segmentDownloader)
      downloadURLs.append(notInDownloadList[i].locationURL)
      
      var segmentModel = M3u8TsSegmentModel()
      segmentModel.duration = segmentDownloaders[i].duration
      segmentModel.locationURL = segmentDownloaders[i].fileName
      segmentModel.index = segmentDownloaders[i].index
      newSegmentArray.append(segmentModel)
      
      tsPlaylist.tsSegmentArray = newSegmentArray
      
      segmentDownloaders[i].startDownload()
      
      tsFilesIndex += 1
    }
  }
  
  func updateLocalM3U8file() {
    checkOrCreatedM3u8Directory()
    
    let filePath = getDocumentsDirectory().appendingPathComponent("Downloads").appendingPathComponent(tsPlaylist.identifier).appendingPathComponent("\(tsPlaylist.identifier).m3u8")
    
    var header = "#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-TARGETDURATION:15\n"
    var content = ""
    
    for i in 0 ..< tsPlaylist.tsSegmentArray.count {
      let segmentModel = tsPlaylist.tsSegmentArray[i]
      
      let length = "#EXTINF:\(segmentModel.duration),\n"
      let fileName = "http://127.0.0.1:8080/\(segmentModel.index).ts\n"
      content += (length + fileName)
    }
    
    header.append(content)
    header.append("#EXT-X-ENDLIST\n")
    
    let writeData: Data = header.data(using: .utf8)!
    try! writeData.write(to: filePath)
  }
  
  private func checkOrCreatedM3u8Directory() {
    let filePath = getDocumentsDirectory().appendingPathComponent("Downloads").appendingPathComponent(tsPlaylist.identifier)
    
    if !FileManager.default.fileExists(atPath: filePath.path) {
      try! FileManager.default.createDirectory(at: filePath, withIntermediateDirectories: true, attributes: nil)
    }
  }
  
  open func deleteAllDownloadedContents() {
    let filePath = getDocumentsDirectory().appendingPathComponent("Downloads").path
    
    if FileManager.default.fileExists(atPath: filePath) {
      try! FileManager.default.removeItem(atPath: filePath)
    } else {
      print("File has already been deleted.")
    }
  }
  
  open func deleteDownloadedContents(with name: String) {
    let filePath = getDocumentsDirectory().appendingPathComponent("Downloads").appendingPathComponent(name).path
    
    if FileManager.default.fileExists(atPath: filePath) {
      try! FileManager.default.removeItem(atPath: filePath)
    } else {
      print("Could not find directory with name: \(name)")
    }
  }
  
  open func pauseDownloadSegment() {
    _ = segmentDownloaders.map { $0.pauseDownload() }
  }
  
  open func cancelDownloadSegment() {
    _ = segmentDownloaders.map { $0.cancelDownload() }
  }
  
  open func resumeDownloadSegment() {
    _ = segmentDownloaders.map { $0.resumeDownload() }
  }
}

extension VideoDownloader: SegmentDownloaderDelegate {
  func segmentDownloadSucceeded(with downloader: SegmentDownloader) {
    downloadedTsFilesCount += 1

    DispatchQueue.main.async {
      self.delegate?.updateProgressLabel(by: self.downloadingProgress)
    }

    updateLocalM3U8file()

    if downloadedTsFilesCount == neededDownloadTsFilesCount {
      delegate?.videoDownloadSucceeded(by: self)
    }
  }
  
  func segmentDownloadFailed(with downloader: SegmentDownloader) {
    delegate?.videoDownloadFailed(by: self)
  }
}
