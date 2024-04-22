package com.jnesis.capacitor.brightcoveplayer.utils

import android.content.Context
import android.view.GestureDetector
import android.view.GestureDetector.SimpleOnGestureListener
import android.view.MotionEvent
import android.view.View
import android.view.View.OnTouchListener
import kotlin.math.abs


open class OnSwipeTouchListener(context: Context?) : OnTouchListener {

    companion object {
        private const val SWIPE_DISTANCE_THRESHOLD = 200
        private const val SWIPE_VELOCITY_THRESHOLD = 100
    }

    private val gestureDetector: GestureDetector

    init {
        gestureDetector = GestureDetector(context, GestureListener())
    }

    protected open fun onSwipeDown() {}

    override fun onTouch(v: View?, event: MotionEvent?): Boolean {
        return gestureDetector.onTouchEvent(event ?: return false)
    }

    private inner class GestureListener : SimpleOnGestureListener() {
        override fun onDown(e: MotionEvent): Boolean {
            return true
        }

        override fun onFling(start: MotionEvent, end: MotionEvent, velocityX: Float, velocityY: Float): Boolean {
            val distanceX = end.x - start.x
            val distanceY = end.y - start.y
            if (abs(distanceX) < abs(distanceY) && abs(distanceY) > SWIPE_DISTANCE_THRESHOLD && abs(velocityY) > SWIPE_VELOCITY_THRESHOLD) {
                if (distanceY > 0) onSwipeDown()
                return true
            }
            return false
        }
    }
}
