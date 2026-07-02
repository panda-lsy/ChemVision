package com.chemvision.chemvision

import com.vivo.llmsdk.LlmConfig
import com.vivo.llmsdk.LlmManager
import com.vivo.llmsdk.TokenCallback
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class BlueLmPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var llmManager: LlmManager? = null
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())
    private val TAG = "BlueLmPlugin"

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.chemvision/bluelm")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        scope.cancel()
        releaseLlm()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "init" -> handleInit(call, result)
            "generate" -> handleGenerate(call, result)
            "interrupt" -> handleInterrupt(result)
            "release" -> handleRelease(result)
            else -> result.notImplemented()
        }
    }

    private fun handleInit(call: MethodCall, result: Result) {
        val modelPath = call.argument<String>("modelPath")
            ?: return result.error("INVALID_ARGS", "modelPath required", null)
        val nCtx = call.argument<Int>("nCtx") ?: 2048
        val nThreads = call.argument<Int>("nThreads") ?: 4
        val npuPower = call.argument<Int>("npuPower") ?: 100

        android.util.Log.d(TAG, "handleInit: path=$modelPath, nCtx=$nCtx")

        scope.launch {
            try {
                val manager = LlmManager()
                val config = LlmConfig()
                config.modelPath = modelPath
                config.nCtx = nCtx
                config.nThreads = nThreads
                config.npuPower = npuPower

                android.util.Log.d(TAG, "Calling LlmManager.init()...")
                val ret = manager.init(config)
                android.util.Log.d(TAG, "LlmManager.init() returned: $ret")

                llmManager = if (ret == 0) manager else null
                withContext(Dispatchers.Main) {
                    result.success(ret)
                }
            } catch (e: Exception) {
                android.util.Log.e(TAG, "init exception: ${e.javaClass.simpleName}: ${e.message}")
                android.util.Log.e(TAG, "stacktrace: ${e.stackTraceToString()}")
                withContext(Dispatchers.Main) {
                    result.error("INIT_FAILED", "${e.javaClass.simpleName}: ${e.message}", null)
                }
            }
        }
    }

    private fun handleGenerate(call: MethodCall, result: Result) {
        val prompt = call.argument<String>("prompt")
            ?: return result.error("INVALID_ARGS", "prompt required", null)
        val manager = llmManager
            ?: return result.error("NOT_INITIALIZED", "BlueLM not initialized", null)

        android.util.Log.d(TAG, "generate: prompt=${prompt.take(50)}...")

        scope.launch {
            try {
                val responseBuilder = StringBuilder()
                val latch = CountDownLatch(1)
                var errorCode: Int? = null
                var errorMsg: String? = null

                // generate() 内部自行起线程执行推理，回调通过 SDK 内部 Handler 派回主线程。
                // 与官方 demo 调用方式保持一致：传真实的 TokenCallback 实例，不用反射/Proxy。
                manager.generate(prompt, object : TokenCallback {
                    override fun onToken(token: String) {
                        responseBuilder.append(token)
                    }

                    override fun onComplete(stats: com.vivo.llmsdk.LlmStats) {
                        android.util.Log.d(TAG, "generate complete")
                        latch.countDown()
                    }

                    override fun onError(code: Int, msg: String) {
                        android.util.Log.e(TAG, "generate error: $code $msg")
                        errorCode = code
                        errorMsg = msg
                        latch.countDown()
                    }
                })

                // 等待推理真正结束，最多等待 60s（端侧模型较慢），避免无限阻塞
                val done = latch.await(60, TimeUnit.SECONDS)
                if (!done) {
                    android.util.Log.w(TAG, "generate latch timeout")
                    manager.interrupt()
                }

                android.util.Log.d(TAG, "generate result: ${responseBuilder.toString().take(100)}")
                withContext(Dispatchers.Main) {
                    if (errorCode != null) {
                        result.error("GENERATE_FAILED", "$errorCode $errorMsg", null)
                    } else {
                        result.success(responseBuilder.toString())
                    }
                }
            } catch (e: Exception) {
                android.util.Log.e(TAG, "generate exception: ${e.message}")
                withContext(Dispatchers.Main) {
                    result.error("GENERATE_FAILED", e.message, null)
                }
            }
        }
    }

    private fun handleInterrupt(result: Result) {
        val manager = llmManager
        if (manager == null) { result.success(null); return }
        try {
            manager.interrupt()
            result.success(null)
        } catch (e: Exception) {
            result.error("INTERRUPT_FAILED", e.message, null)
        }
    }

    private fun handleRelease(result: Result) {
        releaseLlm()
        result.success(null)
    }

    private fun releaseLlm() {
        try {
            llmManager?.release()
        } catch (_: Exception) {}
        llmManager = null
    }
}
