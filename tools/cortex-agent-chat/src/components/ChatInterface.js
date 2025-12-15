import React, { useState, useRef, useEffect } from 'react';
import MessageList from './MessageList';
import MessageInput from './MessageInput';
import ThinkingIndicator from './ThinkingIndicator';
import { sendMessageToAgentStream } from '../services/snowflakeApi';
import './ChatInterface.css';

const ChatInterface = ({ config }) => {
  const [messages, setMessages] = useState([
    {
      id: 1,
      role: 'assistant',
      content: `Hello! I'm your Snowflake Cortex Agent (${config.agentName}). How can I help you today?`,
      timestamp: new Date()
    }
  ]);
  
  const [isLoading, setIsLoading] = useState(false);
  const [isThinking, setIsThinking] = useState(false);
  const [error, setError] = useState(null);
  const messagesEndRef = useRef(null);
  const streamAbortRef = useRef(null);
  const streamErrorHandledRef = useRef(false);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const addMessage = (message) => {
    setMessages((prev) => [...prev, message]);
  };

  const updateMessageContent = (id, updater) => {
    setMessages((prev) =>
      prev.map((msg) =>
        msg.id === id
          ? {
              ...msg,
              content: typeof updater === 'function' ? updater(msg.content) : updater
            }
          : msg
      )
    );
  };

  const handleStreamingResponse = async (content) => {
    const userMessage = {
      id: Date.now(),
      role: 'user',
      content: content.trim(),
      timestamp: new Date()
    };

    addMessage(userMessage);
    setIsLoading(true);
    setIsThinking(true);
    setError(null);

    const assistantMessageId = userMessage.id + 1;
    addMessage({
      id: assistantMessageId,
      role: 'assistant',
      content: '',
      timestamp: new Date()
    });

    try {
      const controller = new AbortController();
      streamAbortRef.current = controller;
      streamErrorHandledRef.current = false;

      await sendMessageToAgentStream(
        config,
        content.trim(),
        {
          onDelta: (chunk) => {
            setIsThinking(false);
            updateMessageContent(assistantMessageId, (existing) => `${existing || ''}${chunk}`);
          },
          onComplete: (result) => {
            updateMessageContent(assistantMessageId, result.content || '');
            streamAbortRef.current = null;
          },
          onError: (streamError) => {
            streamErrorHandledRef.current = true;
            updateMessageContent(
              assistantMessageId,
              `I'm sorry, I encountered an error: ${streamError.message}\n\n💡 Tip: Check the browser console (F12 → Console) for detailed debugging information about the API request.`
            );
            setError(streamError.message);
            streamAbortRef.current = null;
          }
        },
        { signal: controller.signal }
      );
    } catch (err) {
      if (err.name === 'AbortError') {
        updateMessageContent(assistantMessageId, (existing) => existing || '[Request aborted]');
      } else if (!streamErrorHandledRef.current) {
        console.error('Error sending message:', err);
        setError(err.message || 'Failed to send message to the agent');
        updateMessageContent(
          assistantMessageId,
          `I'm sorry, I encountered an error: ${err.message || 'Unknown error occurred'}\n\n💡 Tip: Check the browser console (F12 → Console) for detailed debugging information about the API request.`
        );
      }
    } finally {
      setIsLoading(false);
      setIsThinking(false);
      streamAbortRef.current = null;
    }
  };

  const handleSendMessage = async (content) => {
    if (!content.trim()) return;

    await handleStreamingResponse(content);
  };

  const clearChat = () => {
    if (streamAbortRef.current) {
      streamAbortRef.current.abort();
      streamAbortRef.current = null;
    }

    setMessages([
      {
        id: 1,
        role: 'assistant',
        content: `Hello! I'm your Snowflake Cortex Agent (${config.agentName}). How can I help you today?`,
        timestamp: new Date()
      }
    ]);
    setError(null);
  };

  return (
    <div className="chat-interface">
      <div className="chat-header">
        <div className="agent-info">
          <h3>🤖 {config.agentName}</h3>
          <span className="connection-status">
            Connected to {config.database}.{config.schema}
          </span>
        </div>
        <button className="clear-button" onClick={clearChat}>
          🗑️ Clear Chat
        </button>
      </div>

      <div className="chat-container">
        <MessageList 
          messages={messages} 
          isLoading={isLoading}
        />
        {isThinking && <ThinkingIndicator />}
        <div ref={messagesEndRef} />
      </div>

      {error && (
        <div className="error-banner">
          <span>⚠️ {error}</span>
          <button onClick={() => setError(null)}>✕</button>
        </div>
      )}

      <MessageInput 
        onSendMessage={handleSendMessage}
        isLoading={isLoading}
      />
    </div>
  );
};

export default ChatInterface;
